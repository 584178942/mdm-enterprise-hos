import { ConfigStore } from '../storage/ConfigStore';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'Settings';
const DOMAIN = 0x0001;

interface SettingItem {
  title: string;
  subtitle: string;
  type: 'switch' | 'input' | 'info';
  value?: string | boolean;
  onChange?: (value: string | boolean) => void;
}

@Entry
@Component
struct Settings {
  @State settings: SettingItem[] = [];
  @State mqttServerUri: string = 'tcp://192.168.1.199:1883';
  @State mqttUsername: string = 'admin';
  @State mqttPassword: string = 'admin';
  @State useMockMode: boolean = true;
  @State deviceId: string = '';
  @State configLoaded: boolean = false;

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Settings page about to appear');
    this.loadSettings();
  }

  async loadSettings() {
    try {
      await ConfigStore.init(getContext(this));

      this.mqttServerUri = await ConfigStore.getMqttServerUri();
      this.mqttUsername = await ConfigStore.getMqttUsername();
      this.mqttPassword = await ConfigStore.getMqttPassword();
      this.useMockMode = await ConfigStore.isMockMode();
      this.deviceId = await ConfigStore.getDeviceId();

      this.updateSettingsList();
      this.configLoaded = true;
      hilog.info(DOMAIN, TAG, 'Settings loaded successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to load settings: %{public}s', JSON.stringify(err));
    }
  }

  updateSettingsList() {
    this.settings = [
      {
        title: 'MQTT服务器',
        subtitle: this.mqttServerUri,
        type: 'info'
      },
      {
        title: 'MQTT用户名',
        subtitle: this.mqttUsername,
        type: 'info'
      },
      {
        title: 'MQTT密码',
        subtitle: '******',
        type: 'info'
      },
      {
        title: '使用Mock模式',
        subtitle: this.useMockMode ? '是（开发测试用）' : '否（使用真实MDM API）',
        type: 'info'
      },
      {
        title: '设备ID',
        subtitle: this.deviceId,
        type: 'info'
      }
    ];
  }

  build() {
    Scroll() {
      Column() {
        Text('设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 20 });

        if (!this.configLoaded) {
          LoadingProgress()
            .width(40)
            .height(40)
            .padding({ top: 40 });
          Text('加载中...')
            .fontSize(14)
            .fontColor('#8E8E93')
            .padding({ top: 10 });
        } else {
          // MQTT配置区域
          Column() {
            Text('MQTT配置')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ bottom: 15 });

            this.SettingInfoRow('服务器地址', this.mqttServerUri);
            this.SettingInfoRow('用户名', this.mqttUsername);
            this.SettingInfoRow('密码', '******');

            Button('修改MQTT配置')
              .fontSize(14)
              .width('100%')
              .height(40)
              .backgroundColor('#007AFF')
              .borderRadius(8)
              .margin({ top: 10 })
              .onClick(() => {
                hilog.info(DOMAIN, TAG, 'Modify MQTT config clicked');
              });
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 });

          // MDM配置区域
          Column() {
            Text('MDM配置')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ bottom: 15 });

            Row() {
              Column() {
                Text('Mock模式')
                  .fontSize(16);
                Text('开发阶段使用模拟数据，绕过企业证书限制')
                  .fontSize(12)
                  .fontColor('#8E8E93');
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              Toggle({ type: ToggleType.Switch, isOn: this.useMockMode })
                .selectedColor('#007AFF')
                .onChange(async (isOn: boolean) => {
                  hilog.info(DOMAIN, TAG, 'Mock mode toggled: %{public}s', isOn.toString());
                  this.useMockMode = isOn;
                  await ConfigStore.saveMockMode(isOn);
                  this.updateSettingsList();
                });
            }
            .width('100%');

            Divider()
              .margin({ top: 15, bottom: 15 });   // 修复：vertical → top/bottom

            Row() {
              Column() {
                Text('设备ID')
                  .fontSize(16);
                Text(this.deviceId)
                  .fontSize(12)
                  .fontColor('#8E8E93')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              Button('重置')
                .fontSize(12)
                .height(30)
                .backgroundColor('#FF3B30')
                .borderRadius(6)
                .onClick(async () => {
                  hilog.info(DOMAIN, TAG, 'Reset device ID clicked');
                  const newDeviceId = 'mdm_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 8);
                  await ConfigStore.saveDeviceId(newDeviceId);
                  this.deviceId = newDeviceId;
                  this.updateSettingsList();
                });
            }
            .width('100%');
          }
          .width('100%')
          .padding(16)
          .margin({ top: 16 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 });

          // 关于区域
          Column() {
            Text('关于')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ bottom: 15 });

            this.SettingInfoRow('应用名称', 'MDM企业移动管理');
            this.SettingInfoRow('版本', '1.0.0');
            this.SettingInfoRow('平台', 'HarmonyOS Next 6.0+');
            this.SettingInfoRow('API版本', 'API 14+');

            Divider()
              .margin({ top: 15, bottom: 15 });   // 修复：vertical → top/bottom

            Text('MDM Kit 企业设备管理解决方案')
              .fontSize(12)
              .fontColor('#8E8E93')
              .width('100%')
              .textAlign(TextAlign.Center);

            Text('基于华为HarmonyOS MDM Kit构建')
              .fontSize(12)
              .fontColor('#8E8E93')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 4 });
          }
          .width('100%')
          .padding(16)
          .margin({ top: 16 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 });

          // 证书申请说明
          Column() {
            Text('升级到正式模式')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ bottom: 15 });

            Text('当前运行在 Mock 模式，所有MDM功能为模拟实现。')
              .fontSize(14)
              .fontColor('#FF9500')
              .width('100%')
              .padding({ bottom: 10 });

            Text('要使用真实的MDM能力，需要:')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ bottom: 8 });

            Text('1. 访问华为开发者联盟官网')
              .fontSize(14)
              .fontColor('#8E8E93')
              .width('100%');
            Text('2. 申请企业MDM应用资质')
              .fontSize(14)
              .fontColor('#8E8E93')
              .width('100%');
            Text('3. 获取 MANAGE_ENTERPRISE_DEVICE_ADMIN 权限')
              .fontSize(14)
              .fontColor('#8E8E93')
              .width('100%');
            Text('4. 配置企业签名证书(.p7b)')
              .fontSize(14)
              .fontColor('#8E8E93')
              .width('100%');
            Text('5. 将 MdmApiFactory.USE_MOCK 改为 false')
              .fontSize(14)
              .fontColor('#8E8E93')
              .width('100%');
          }
          .width('100%')
          .padding(16)
          .margin({ top: 16 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 });
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F2F2F7');
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off);
  }

  @Builder
  SettingInfoRow(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor('#8E8E93');
      Blank();
      Text(value)
        .fontSize(14)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 });
  }
}