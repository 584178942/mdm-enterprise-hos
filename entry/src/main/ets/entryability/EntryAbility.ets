import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ConfigStore } from '../storage/ConfigStore';
import { getMqttBackgroundService } from '../service/MqttBackgroundService';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryAbility'

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, 'Ability onCreate');

    try {
      await ConfigStore.init(this.context)
      hilog.info(DOMAIN, TAG, 'ConfigStore initialized');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize ConfigStore: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
    try {
      const service = getMqttBackgroundService()
      service.stop()
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to stop service: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    hilog.info(DOMAIN, TAG, 'Starting MQTT background service...');
    const service = getMqttBackgroundService()
    service.start(this.context).then(() => {
      hilog.info(DOMAIN, TAG, 'MQTT background service started successfully');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to start MQTT background service: %{public}s', JSON.stringify(err));
    })
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
