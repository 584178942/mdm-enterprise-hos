import EnterpriseAdminExtensionAbility from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'EnterpriseAdminAbility'
const DOMAIN = 0x0001

/**
 * 企业管理员扩展能力
 * 用于MDM设备管理，当管理员启用/禁用或应用安装/卸载时会收到回调
 */
export default class EnterpriseAdminAbility extends EnterpriseAdminExtensionAbility {
  /**
   * 当设备管理员应用启用时调用
   * 此回调后可以调用MDM Kit API
   */
  onAdminEnabled(): void {
    hilog.info(DOMAIN, TAG, 'MDM管理员已启用')
    // TODO: 初始化MDM相关配置，设置初始策略
  }

  /**
   * 当设备管理员应用禁用时调用
   */
  onAdminDisabled(): void {
    hilog.info(DOMAIN, TAG, 'MDM管理员已禁用')
    // TODO: 清理MDM相关配置
  }

  /**
   * 当应用安装时调用
   * @param bundleName 安装的应用包名
   */
  onBundleAdded(bundleName: string): void {
    hilog.info(DOMAIN, TAG, `应用已安装: %{public}s`, bundleName)
    // TODO: 记录或上报应用安装事件
  }

  /**
   * 当应用卸载时调用
   * @param bundleName 卸载的应用包名
   */
  onBundleRemoved(bundleName: string): void {
    hilog.info(DOMAIN, TAG, `应用已卸载: %{public}s`, bundleName)
    // TODO: 记录或上报应用卸载事件
  }
}
