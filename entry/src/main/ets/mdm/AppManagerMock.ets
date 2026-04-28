import { IAppManager, IAppInfo, OperationResult, AppListResult } from './IDeviceController'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'AppManagerMock'
const DOMAIN = 0x0001

/**
 * 应用管理Mock实现
 * 用于开发阶段验证业务流程
 */
export class AppManagerMock implements IAppManager {
  async install(apkPath: string): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Install app from: %{public}s', apkPath)
    return { success: true, message: `应用安装触发成功(Mock): ${apkPath}` }
  }

  async uninstall(bundleName: string): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Uninstall app: %{public}s', bundleName)
    return { success: true, message: `应用卸载触发成功(Mock): ${bundleName}` }
  }

  async getAppList(): Promise<AppListResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Get app list')
    // 返回模拟应用列表
    const mockApps: IAppInfo[] = [
      { bundleName: 'com.huawei.huaweiweather', appName: '华为天气' },
      { bundleName: 'com.huawei.appmarket', appName: '应用市场' },
      { bundleName: 'com.tencent.mm', appName: '微信' },
      { bundleName: 'com.alipay.wallet', appName: '支付宝' }
    ]
    return { success: true, message: '查询成功(Mock)', apps: mockApps }
  }
}
