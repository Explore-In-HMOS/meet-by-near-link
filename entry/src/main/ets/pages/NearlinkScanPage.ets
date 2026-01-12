import { scan, advertising, dataTransfer, ssap, constant, remoteDevice } from '@kit.NearLinkKit';
import { promptAction, UIContext } from '@kit.ArkUI';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';

import { BusinessCard, SimpleDevice, MANUFACTURER_ID, SERVICE_UUID, LOG_TAG, DOMAIN_ID } from '../model/NearLinkModels';
import { NearLinkHelper } from '../utils/NearLinkHelper';
import { SimpleDeviceClass } from '../view/Components';
import { MainControlViewBuilder, ReceivedCardViewBuilder } from '../view/NearlinkViewBuilders';

@Component
export struct NearlinkScanPage {
  @Consume('pageInfos') pageInfos: NavPathStack;
  @State currentMode: 'NONE' | 'SENDER' | 'RECEIVER' = 'NONE';
  @State statusLog: ResourceStr = $r('app.string.nearlink_default_status');
  @State devices: Array<SimpleDeviceClass> = [];
  @State isSending: boolean = false;
  @State receivedCard: BusinessCard | null = null;
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
        promptAction.openToast({ message: $r('app.string.nearlink_toast_sent'), duration: 2000 });
        await NearLinkHelper.delay(1000);

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

  build() {
    NavDestination() {
      if (this.receivedCard !== null) {
        ReceivedCardViewBuilder(
          this.receivedCard,
          () => { // OnClose
            this.receivedCard = null;
            this.statusLog = 'Ready';
          },
          () => { // OnSave
            this.receivedCard = null;
          }
        )
      } else {
        MainControlViewBuilder(
          this.statusLog,
          this.currentMode,
          this.devices,
          () => this.startReceiverMode(), // onStartReceiver
          () => this.startSenderMode(),   // onStartSender
          () => this.stopEverything(),    // onStop
          (addr: string) => this.connectAndSend(addr) // onConnect
        )
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#000000')
  }
}