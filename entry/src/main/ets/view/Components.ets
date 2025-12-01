import { SimpleDevice } from '../model/NearLinkModels';

@Component
export struct MenuButton {
  @Prop title: ResourceStr;
  @Prop color: string;
  action: () => void = () => {};

  build() {
    Button() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
    .width('100%')
    .height(64)
    .backgroundColor(this.color)
    .borderRadius(18)
    .onClick(() => {
      this.action();
    })
    .shadow({ radius: 8, color: this.color, offsetY: 2 })
  }
}

@Component
export struct DeviceCard {
  @ObjectLink device: SimpleDeviceClass; // Note: Use Observed Class in real app, strictly simple here
  onConnect: () => void = () => {};

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 40, height: 40 }).fill('#424242')
        Text(this.device.name.charAt(0).toUpperCase())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .margin({ right: 12 })

      Column() {
        Text(this.device.name)
          .fontSize(15)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(this.device.address)
          .fontSize(11)
          .fontColor('#9E9E9E');
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${this.device.rssi}`)
        .fontSize(10)
        .fontColor('#757575')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#212121')
    .borderRadius(16)
    .onClick(this.onConnect)
  }
}

@Observed
export class SimpleDeviceClass {
  address: string = '';
  name: string = '';
  rssi: number = 0;

  constructor(d: SimpleDevice) {
    this.address = d.address;
    this.name = d.name;
    this.rssi = d.rssi;
  }
}

@Component
export struct InfoRow {
  @Prop label: string;
  @Prop value: string;

  build() {
    Column() {
      Text(this.label)
        .fontSize(10)
        .fontColor('#757575')
      Text(this.value)
        .fontSize(13)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12 })
  }
}