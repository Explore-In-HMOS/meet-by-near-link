import { AbilityConstant, ConfigurationConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import abilityAccessCtrl, { PermissionRequestResult } from '@ohos.abilityAccessCtrl';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    // 🔵 NearLink iznini runtime'da iste
    void this.requestNearLinkPermission();
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  // 🔐 ACCESS_NEARLINK iznini kullanıcıdan isteyen fonksiyon
  private async requestNearLinkPermission(): Promise<void> {
    const abilityContext: common.UIAbilityContext = this.context as common.UIAbilityContext;
    const atManager = abilityAccessCtrl.createAtManager();

    try {
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
        abilityContext,
        ['ohos.permission.ACCESS_NEARLINK']
      );

      hilog.info(DOMAIN, 'testTag', 'NearLink permission result: %{public}s', JSON.stringify(result));

      const granted: boolean = result.authResults.some((value: number): boolean => value === 0);
      if (!granted) {
        hilog.error(DOMAIN, 'testTag', '%{public}s', 'ACCESS_NEARLINK not granted by user');
      }
    } catch (err) {
      hilog.error(
        DOMAIN,
        'testTag',
        'requestPermissionsFromUser failed: %{public}s',
        JSON.stringify(err)
      );
    }
  }
}
