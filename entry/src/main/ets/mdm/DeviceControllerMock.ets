import { IDeviceController, OperationResult } from './IDeviceController'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'DeviceControllerMock'
const DOMAIN = 0x0001

/**
 * 设备控制Mock实现
 * 用于开发阶段验证业务流程，无需企业MDM证书
 */
export class DeviceControllerMock implements IDeviceController {
  async lock(mainText: string, subText: string): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Lock device: %{public}s - %{public}s', mainText, subText)
    return { success: true, message: '设备已锁定(Mock)' }
  }

  async unlock(): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Unlock device')
    return { success: true, message: '设备已解锁(Mock)' }
  }

  async wipe(): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Factory reset')
    return { success: true, message: '恢复出厂设置(Mock)' }
  }

  async reboot(): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Reboot device')
    return { success: true, message: '设备重启(Mock)' }
  }

  async resetPassword(password: string): Promise<OperationResult> {
    hilog.info(DOMAIN, TAG, '[MOCK] Reset password to: %{public}s', password)
    return { success: true, message: `密码已重置为: ${password}(Mock)` }
  }
}
