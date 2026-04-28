import { IRestrictionManager, OperationResult } from './IDeviceController'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'RestrictionManagerMock'
const DOMAIN = 0x0001

/**
 * 限制策略Mock实现
 * 用于开发阶段验证业务流程
 */
export class RestrictionManagerMock implements IRestrictionManager {
  async setWifiDisabled(disabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set WiFi disabled: %{public}s', disabled.toString())
    return { success: true, message: `WiFi ${disabled ? '禁用' : '启用'}成功(Mock)` }
  }

  async setMobileDataDisabled(disabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set mobile data disabled: %{public}s', disabled.toString())
    return { success: true, message: `移动数据 ${disabled ? '禁用' : '启用'}成功(Mock)` }
  }

  async setBluetoothDisabled(disabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set bluetooth disabled: %{public}s', disabled.toString())
    return { success: true, message: `蓝牙 ${disabled ? '禁用' : '启用'}成功(Mock)` }
  }

  async setGpsEnabled(enabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set GPS enabled: %{public}s', enabled.toString())
    return { success: true, message: `GPS ${enabled ? '启用' : '禁用'}成功(Mock)` }
  }

  async setCameraDisabled(disabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set camera disabled: %{public}s', disabled.toString())
    return { success: true, message: `相机 ${disabled ? '禁用' : '启用'}成功(Mock)` }
  }

  async setMicrophoneDisabled(disabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set microphone disabled: %{public}s', disabled.toString())
    return { success: true, message: `麦克风 ${disabled ? '禁用' : '启用'}成功(Mock)` }
  }

  async setUsbDebugDisabled(disabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set USB debug disabled: %{public}s', disabled.toString())
    return { success: true, message: `USB调试 ${disabled ? '禁用' : '启用'}成功(Mock)` }
  }

  async setScreenshotDisabled(disabled: boolean): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Set screenshot disabled: %{public}s', disabled.toString())
    return { success: true, message: `截图 ${disabled ? '禁用' : '启用'}成功(Mock)` }
  }
}
