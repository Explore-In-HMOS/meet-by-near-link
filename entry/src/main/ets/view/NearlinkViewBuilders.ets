import { BusinessCard } from '../model/NearLinkModels';
import { MenuButton, DeviceCard, InfoRow, SimpleDeviceClass } from '../view/Components';
import { promptAction } from '@kit.ArkUI';

@Builder
export function MainControlViewBuilder(
  statusLog: ResourceStr,
  currentMode: 'NONE' | 'SENDER' | 'RECEIVER',
  devices: SimpleDeviceClass[],
  onStartReceiver: () => void,
  onStartSender: () => void,
  onStop: () => void,
  onConnect: (address: string) => void
) {
  Scroll() {
    Column() {
      Text($r('app.string.nearlink_title'))
        .textAlign(TextAlign.Center)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0A59F7')
        .width('100%')
        .margin({ top: 24, bottom: 8 })

      Text(statusLog)
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
          currentMode === 'RECEIVER' ? '#2E7D32' :
            (currentMode === 'SENDER' ? '#1565C0' : '#424242')
        )
        .borderRadius(20)
        .margin({ bottom: 24 })
        .textAlign(TextAlign.Center)

      if (currentMode === 'NONE') {
        Column({ space: 12 }) {
          MenuButton({
            title: $r('app.string.nearlink_mode_receive'),
            color: '#2E7D32',
            action: onStartReceiver
          })
          MenuButton({
            title: $r('app.string.nearlink_mode_send'),
            color: '#1565C0',
            action: onStartSender
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

      } else if (currentMode === 'RECEIVER') {
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
            .onClick(onStop)
        }

      } else if (currentMode === 'SENDER') {
        if (devices.length === 0) {
          Column() {
            LoadingProgress().width(40).height(40).color('#0A59F7')
            Text('Searching...')
              .fontSize(12)
              .fontColor(Color.Gray)
              .margin({ top: 10 })
          }.margin({ bottom: 20 })
        } else {
          Column({ space: 8 }) {
            ForEach(devices, (dev: SimpleDeviceClass) => {
              DeviceCard({
                device: dev,
                onConnect: () => onConnect(dev.address)
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
          .onClick(onStop)
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

/**
 * Kart Alındı Ekranı Builder'ı
 */
@Builder
export function ReceivedCardViewBuilder(
  card: BusinessCard,
  onClose: () => void,
  onSave: () => void
) {
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
          Text(card.fullName.charAt(0).toUpperCase())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .margin({ bottom: 12 })

        Text(card.fullName)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)

        Text(card.title)
          .fontSize(14)
          .fontColor('#B0BEC5')
          .margin({ top: 4 })
          .textAlign(TextAlign.Center)

        Text(card.company)
          .fontSize(12)
          .fontColor('#0A59F7')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 4, bottom: 16 })

        Divider().color('#424242').width('80%').margin({ bottom: 16 })

        Column({ space: 8 }) {
          InfoRow({ label: 'Phone', value: card.phone })
          InfoRow({ label: 'Email', value: card.email })
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
          .onClick(onClose)

        Button('Save')
          .backgroundColor('#0A59F7')
          .layoutWeight(1)
          .height(44)
          .borderRadius(22)
          .onClick(() => {
            promptAction.openToast({ message: 'Saved to Contacts!', duration: 1500 });
            setTimeout(() => {
              onSave();
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