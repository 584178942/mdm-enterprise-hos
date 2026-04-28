import { IInfoQuerier, IDeviceInfo, IAppInfo, OperationResult, AppListResult, DeviceInfoResult } from './IDeviceController'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'InfoQuerierMock'
const DOMAIN = 0x0001

/**
 * 信息查询Mock实现
 * 用于开发阶段验证业务流程
 */
export class InfoQuerierMock implements IInfoQuerier {
  async getDeviceInfo(): Promise<DeviceInfoResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Get device info')
    const mockDeviceInfo: IDeviceInfo = {
      deviceId: 'mock_device_' + Date.now().toString(36),
      manufacturer: '华为(Mock)',
      model: 'Mate 60 Pro(Mock)',
      deviceName: '我的设备(Mock)',
      osVersion: 'HarmonyOS 4.0(Mock)',
      sdkApiVersion: 'API 14(Mock)',
      batteryLevel: Math.floor(Math.random() * 100),
      isCharging: Math.random() > 0.5,
      networkType: 'WiFi(Mock)',
      isScreenOn: true,
      lastOnlineTime: Date.now()
    }
    return { success: true, message: '查询成功(Mock)', data: mockDeviceInfo }
  }

  async getAppList(): Promise<AppListResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Get app list')
    const mockApps: IAppInfo[] = [
      { bundleName: 'com.huawei.huaweiweather', appName: '华为天气' },
      { bundleName: 'com.huawei.appmarket', appName: '应用市场' },
      { bundleName: 'com.tencent.mm', appName: '微信' },
      { bundleName: 'com.alipay.wallet', appName: '支付宝' },
      { bundleName: 'com.taobao.taobao4', appName: '淘宝' },
      { bundleName: 'com.baidu.map', appName: '百度地图' }
    ]
    return { success: true, message: '查询成功(Mock)', apps: mockApps }
  }
}
