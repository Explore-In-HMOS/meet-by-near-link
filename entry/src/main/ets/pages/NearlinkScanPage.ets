import { scan, advertising, dataTransfer, ssap, constant, remoteDevice } from '@kit.NearLinkKit';
import { promptAction, UIContext } from '@kit.ArkUI';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';

// Imports from modules
import { BusinessCard, SimpleDevice, MANUFACTURER_ID, SERVICE_UUID, LOG_TAG, DOMAIN_ID } from '../model/NearLinkModels';
import { NearLinkHelper } from '../utils/NearLinkHelper';
import { MenuButton, DeviceCard, SimpleDeviceClass, InfoRow } from '../view/Components';

@Component
export struct NearlinkScanPage {
  @Consume('pageInfos') pageInfos: NavPathStack;
  // --- STATE ---
  @State currentMode: 'NONE' | 'SENDER' | 'RECEIVER' = 'NONE';
  @State statusLog: ResourceStr = $r('app.string.nearlink_default_status');
  @State devices: Array<SimpleDeviceClass> = []; // Changed to Class for Observability
  @State isSending: boolean = false;
  @State receivedCard: BusinessCard | null = null;
  // Local Data
  private myProfile: BusinessCard = {
    fullName: 'Baris Tuzemen',
    title: 'HarmonyOS Developer',
    company: 'Huawei.',
    phone: '+90 555 123 45 67',
    email: 'Baris@example.com',
    shareDate: 0
  };
  private uiContext: UIContext | null = null;
  private ssapServer: ssap.Server | null = null;
  private advHandle: number = -1;
  private connectionParams: dataTransfer.ConnectionParams | null = null;

  aboutToAppear(): void {
    // UIContext'i alıp değişkene atıyoruz (runScopedTask için gerekli)
    this.uiContext = this.getUIContext();
    this.reqPermissions();
    try {
      dataTransfer.createPort(SERVICE_UUID);
    } catch (err) { /* ignore reuse */
    }
  }

  aboutToDisappear(): void {
    this.stopEverything();
  }

  // --- LOGIC METHODS (Kept in page for simplicity of accessing State) ---

  private async stopEverything(): Promise<void> {
    try {
      await scan.stopScan();
    } catch (_) {
    }
    try {
      if (this.advHandle !== -1) {
        await advertising.stopAdvertising(this.advHandle);
        this.advHandle = -1;
      }
    } catch (_) {
    }
    if (this.ssapServer) {
      try {
        this.ssapServer.removeService(SERVICE_UUID);
        this.ssapServer.close();
      } catch (_) {
      }
      this.ssapServer = null;
    }

    // Remove Listeners
    try {
      dataTransfer.off('connectionStateChanged');
    } catch (_) {
    }
    try {
      dataTransfer.off('readData');
    } catch (_) {
    }

    if (this.connectionParams) {
      try {
        await dataTransfer.disconnect(this.connectionParams);
      } catch (_) {
      }
    }

    this.connectionParams = null;
    this.currentMode = 'NONE';
    this.statusLog = $r('app.string.nearlink_default_status');
    this.receivedCard = null;
  }

  private async startReceiverMode(): Promise<void> {
    await this.stopEverything();
    this.updateLog($r('app.string.nearlink_switching'));
    await NearLinkHelper.delay(1000);
    this.currentMode = 'RECEIVER';
    this.updateLog($r('app.string.nearlink_receiver_start'));

    try {
      this.ssapServer = ssap.createServer();
      const property: ssap.Property = {
        serviceUuid: SERVICE_UUID,
        propertyUuid: '37BEA880-FC70-11EA-B720-000000001234',
        value: new Uint8Array([1]).buffer,
        operation: ssap.Operation.READABLE
      };
      this.ssapServer.addService({ serviceUuid: SERVICE_UUID, properties: [property] });

      dataTransfer.on('connectionStateChanged', (data) => {
        if (data.state === constant.ConnectionState.STATE_CONNECTED) {
          this.updateLog('Receiving Data...');
        }
      });

      dataTransfer.on('readData', (params) => {
        const card = NearLinkHelper.decodeData(params.data);
        if (card) {
          this.uiContext?.runScopedTask(() => {
            this.receivedCard = card;
          });
        }
      });

      const advParams: advertising.AdvertisingParams = {
        advertisingSettings: {
          interval: 160,
          power: advertising.TxPowerMode.ADV_TX_POWER_HIGH,
          isConnectable: true
        },
        advertisingData: {
          serviceUuids: [SERVICE_UUID],
          manufacturerData: [
            {
              manufacturerId: MANUFACTURER_ID,
              manufacturerData: new Uint8Array([1]).buffer
            }
          ],
          includeDeviceName: true
        }
      };

      await advertising.startAdvertising(advParams);
      this.updateLog($r('app.string.nearlink_receiver_ready'));
    } catch (err) {
      this.updateLog('Error starting server');
    }
  }

  private async startSenderMode(): Promise<void> {
    await this.stopEverything();
    this.currentMode = 'SENDER';
    this.devices = [];
    this.updateLog($r('app.string.nearlink_scanning'));

    try {
      scan.on('deviceFound', (results) => {
        this.uiContext?.runScopedTask(() => {
          results.forEach(item => {
            if (!item.deviceName) {
              return;
            }
            const exists = this.devices.some(d => d.address === item.address);
            if (!exists) {
              // Convert to Class for UI binding
              this.devices.push(new SimpleDeviceClass({
                address: item.address,
                name: item.deviceName,
                rssi: item.rssi
              }));
            }
          });
        });
      });
      await scan.startScan([{ manufacturerId: MANUFACTURER_ID }], { scanMode: scan.ScanMode.SCAN_MODE_BALANCED });
    } catch (err) {
      this.updateLog('Scan Error');
    }
  }

  private async connectAndSend(targetAddress: string): Promise<void> {
    if (this.isSending) {
      return;
    }
    this.isSending = true;

    try {
      const conn: dataTransfer.ConnectionParams = { address: targetAddress, uuid: SERVICE_UUID, mtu: 1024 };
      try {
        await remoteDevice.createRemoteDevice(conn.address).startPairing();
      } catch (_) {
      }

      const listener = (data: dataTransfer.ConnectionResult) => {
        // Simplify logging for now
        if (data.state === constant.ConnectionState.STATE_CONNECTED) {
          this.updateLog('Connected');
        }
      };
      dataTransfer.on('connectionStateChanged', listener);

      try {
        this.updateLog($r('app.string.nearlink_status_connecting_to'));
        await dataTransfer.connect(conn);
        this.updateLog($r('app.string.nearlink_connected_sending'));
        await NearLinkHelper.delay(300);

        this.myProfile.shareDate = Date.now();
        const dataParams: dataTransfer.DataParams = {
          address: conn.address,
          uuid: conn.uuid,
          data: NearLinkHelper.encodeData(this.myProfile).buffer
        };

        await dataTransfer.writeData(dataParams);
        this.updateLog($r('app.string.nearlink_send_success'));
        promptAction.showToast({ message: $r('app.string.nearlink_toast_sent'), duration: 2000 });
        await NearLinkHelper.delay(1000);

        // Disconnect
        if (conn) {
          try {
            await dataTransfer.disconnect(conn);
          } catch (_) {
          }
        }

      } catch (err) {
        this.updateLog('Failed to send');
      } finally {
        dataTransfer.off('connectionStateChanged', listener);
      }
    } finally {
      this.isSending = false;
    }
  }

  updateLog(msg: ResourceStr): void {
    this.uiContext?.runScopedTask(() => {
      this.statusLog = msg;
    });
  }

  private async reqPermissions(): Promise<void> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;

      await atManager.requestPermissionsFromUser(context,
        ['ohos.permission.ACCESS_NEARLINK', 'ohos.permission.DISTRIBUTED_DATASYNC',
          'ohos.permission.ACCESS_BLUETOOTH']);
    } catch (_) {
    }
  }

  // --- UI BUILDER ---
  build() {
    NavDestination() {
      if (this.receivedCard !== null) {
        this.ReceivedCardView()
      } else {
        this.MainControlView()
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#000000')
  }

  @Builder
  MainControlView() {
    Scroll() {
      Column() {
        Text($r('app.string.nearlink_title'))
          .textAlign(TextAlign.Center)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0A59F7')
          .width('100%')
          .margin({ top: 24, bottom: 8 })

        Text(this.statusLog)
          .fontSize(11)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .padding({
            left: 14,
            right: 14,
            top: 6,
            bottom: 6
          })
          .backgroundColor(
            this.currentMode === 'RECEIVER' ? '#2E7D32' :
              (this.currentMode === 'SENDER' ? '#1565C0' : '#424242')
          )
          .borderRadius(20)
          .margin({ bottom: 24 })
          .textAlign(TextAlign.Center)

        if (this.currentMode === 'NONE') {
          Column({ space: 12 }) {
            MenuButton({
              title: $r('app.string.nearlink_mode_receive'),
              color: '#2E7D32',
              action: () => this.startReceiverMode()
            })
            MenuButton({
              title: $r('app.string.nearlink_mode_send'),
              color: '#1565C0',
              action: () => this.startSenderMode()
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

        } else if (this.currentMode === 'RECEIVER') {
          Column() {
            Stack() {
              Circle({ width: 120, height: 120 }).fillOpacity(0).stroke('#2E7D32').strokeWidth(1).opacity(0.3)
              Circle({ width: 80, height: 80 }).fillOpacity(0).stroke('#2E7D32').strokeWidth(1).opacity(0.6)
              Circle({ width: 10, height: 10 }).fill('#4CAF50')
            }
            .margin({ bottom: 24 })

            Text($r('app.string.nearlink_receiver_ready'))
              .fontSize(12)
              .fontColor(Color.Gray)
              .margin({ bottom: 20 })

            Button($r('app.string.nearlink_btn_cancel'))
              .backgroundColor('#D32F2F')
              .width('70%')
              .height(44)
              .borderRadius(22)
              .onClick(() => this.stopEverything())
          }

        } else if (this.currentMode === 'SENDER') {
          if (this.devices.length === 0) {
            Column() {
              LoadingProgress().width(40).height(40).color('#0A59F7')
              Text('Searching...')
                .fontSize(12)
                .fontColor(Color.Gray)
                .margin({ top: 10 })
            }.margin({ bottom: 20 })
          } else {
            Column({ space: 8 }) {
              ForEach(this.devices, (dev: SimpleDeviceClass) => {
                DeviceCard({
                  device: dev,
                  onConnect: () => this.connectAndSend(dev.address)
                })
              }, (dev: SimpleDeviceClass) => dev.address)
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
            .margin({ bottom: 20 })
          }

          Button($r('app.string.nearlink_btn_cancel'))
            .backgroundColor('#D32F2F')
            .width('70%')
            .height(44)
            .borderRadius(22)
            .onClick(() => this.stopEverything())
        }
      }
      .width('100%')
      .padding({ bottom: 60 })
      .alignItems(HorizontalAlign.Center)
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
  }

  @Builder
  ReceivedCardView() {
    Scroll() {
      Column() {
        Image($r('app.media.profile'))
          .width(48)
          .height(48)
          .fillColor('#4CAF50')
          .margin({ top: 24, bottom: 16 })

        Text('Card Received!')
          .fontSize(14)
          .fontColor('#4CAF50')
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 16 })

        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Circle({ width: 60, height: 60 }).fill('#1565C0')
            Text(this.receivedCard!.fullName.charAt(0).toUpperCase())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .margin({ bottom: 12 })

          Text(this.receivedCard!.fullName)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)

          Text(this.receivedCard!.title)
            .fontSize(14)
            .fontColor('#B0BEC5')
            .margin({ top: 4 })
            .textAlign(TextAlign.Center)

          Text(this.receivedCard!.company)
            .fontSize(12)
            .fontColor('#0A59F7')
            .fontWeight(FontWeight.Medium)
            .margin({ top: 4, bottom: 16 })

          Divider().color('#424242').width('80%').margin({ bottom: 16 })

          Column({ space: 8 }) {
            InfoRow({ label: 'Phone', value: this.receivedCard!.phone })
            InfoRow({ label: 'Email', value: this.receivedCard!.email })
          }
          .width('100%')
        }
        .width('90%')
        .padding(16)
        .backgroundColor('#212121')
        .borderRadius(16)
        .margin({ bottom: 20 })

        Row({ space: 12 }) {
          Button('Close')
            .backgroundColor('#424242')
            .layoutWeight(1)
            .height(44)
            .borderRadius(22)
            .onClick(() => {
              this.receivedCard = null;
              this.statusLog = 'Ready';
            })

          Button('Save')
            .backgroundColor('#0A59F7')
            .layoutWeight(1)
            .height(44)
            .borderRadius(22)
            .onClick(() => {
              promptAction.showToast({ message: 'Saved to Contacts!', duration: 1500 });
              setTimeout(() => {
                this.receivedCard = null;
              }, 1500);
            })
        }
        .width('90%')
        .margin({ bottom: 40 })

      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}