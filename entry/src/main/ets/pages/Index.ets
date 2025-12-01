import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { NearlinkScanPage } from './NearlinkScanPage';

@Entry
@Component
struct Index {
  private readonly logTag: string = 'Index';
  private readonly domainId: number = 0x0000;

  @Provide('pageInfos')
  pageInfos: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    hilog.info(this.domainId, this.logTag, `${this.logTag} aboutToAppear`);
  }

  @Builder
  PageMap(name: string, params?: Record<string, Object>): void {
    if (name === 'NearlinkScanPage') {
      NearlinkScanPage({});
    } else {
      NearlinkScanPage({});
    }
  }

  build() {
    Navigation(this.pageInfos) {
    }
    .onAppear(() => {
      this.pageInfos.pushPathByName('NearlinkScanPage', null, true);

      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        atManager.requestPermissionsFromUser(context, ['ohos.permission.ACCESS_NEARLINK']);
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        hilog.error(
          this.domainId,
          this.logTag,
          `requestPermissionsFromUser failed: code=${e.code}, msg=${e.message}`
        );
      }
    })
    .titleMode(NavigationTitleMode.Free)
    .hideTitleBar(true)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
  }
}
