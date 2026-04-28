import { CommandMessage } from './CommandParser'
import { CommandResult } from './CommandResult'
import { MdmApiFactory } from '../mdm/MdmApiFactory'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'CommandHandler'
const DOMAIN = 0x0001

/**
 * 命令处理器
 * 负责解析MQTT消息并分发到对应的MDM模块执行
 */
export class CommandHandler {
  private deviceCtrl = MdmApiFactory.getDeviceController()
  private appMgr = MdmApiFactory.getAppManager()
  private restrictMgr = MdmApiFactory.getRestrictionManager()
  private infoQuerier = MdmApiFactory.getInfoQuerier()

  /**
   * 处理命令
   * @param cmd 命令消息
   * @returns 命令执行结果
   */
  async handle(cmd: CommandMessage): Promise<CommandResult> {
    hilog.info(DOMAIN, TAG, 'Handling command: %{public}s', cmd.toString())

    try {
      let result: CommandResult

      switch (cmd.action) {
        // 设备控制命令
        case 'lock':
          result = await this.handleLock(cmd)
          break
        case 'unlock':
          result = await this.handleUnlock(cmd)
          break
        case 'wipe':
          result = await this.handleWipe(cmd)
          break
        case 'reboot':
          result = await this.handleReboot(cmd)
          break
        case 'reset_password':
          result = await this.handleResetPassword(cmd)
          break

        // 应用管理命令
        case 'install_app':
          result = await this.handleInstallApp(cmd)
          break
        case 'uninstall_app':
          result = await this.handleUninstallApp(cmd)
          break
        case 'get_app_list':
          result = await this.handleGetAppList(cmd)
          break

        // 限制策略命令
        case 'disable_wifi':
          result = await this.handleDisableWifi(cmd, true)
          break
        case 'enable_wifi':
          result = await this.handleDisableWifi(cmd, false)
          break
        case 'disable_mobile_data':
          result = await this.handleDisableMobileData(cmd, true)
          break
        case 'enable_mobile_data':
          result = await this.handleDisableMobileData(cmd, false)
          break
        case 'set_gps':
          result = await this.handleSetGps(cmd)
          break
        case 'set_bluetooth':
          result = await this.handleSetBluetooth(cmd)
          break
        case 'disable_camera':
          result = await this.handleDisableCamera(cmd, true)
          break
        case 'enable_camera':
          result = await this.handleDisableCamera(cmd, false)
          break
        case 'disable_microphone':
          result = await this.handleDisableMicrophone(cmd, true)
          break
        case 'enable_microphone':
          result = await this.handleDisableMicrophone(cmd, false)
          break
        case 'disable_usb_debug':
          result = await this.handleDisableUsbDebug(cmd, true)
          break
        case 'enable_usb_debug':
          result = await this.handleDisableUsbDebug(cmd, false)
          break
        case 'disable_screenshot':
          result = await this.handleDisableScreenshot(cmd, true)
          break
        case 'enable_screenshot':
          result = await this.handleDisableScreenshot(cmd, false)
          break

        // 信息查询命令
        case 'get_device_info':
          result = await this.handleGetDeviceInfo(cmd)
          break

        // 未知命令
        default:
          hilog.warn(DOMAIN, TAG, 'Unknown command action: %{public}s', cmd.action)
          result = CommandResult.failure(cmd.commandId, cmd.action, `未知命令: ${cmd.action}`)
      }

      hilog.info(DOMAIN, TAG, 'Command handled: %{public}s', result.toString())
      return result
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Command handling error: %{public}s', JSON.stringify(err))
      return CommandResult.failure(cmd.commandId, cmd.action, `执行异常: ${err}`)
    }
  }

  // 设备控制处理

  private async handleLock(cmd: CommandMessage): Promise<CommandResult> {
    const mainText = cmd.getString('mainText', '设备已锁定')
    const subText = cmd.getString('subText', '请联系管理员')
    const res = await this.deviceCtrl.lock(mainText, subText)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleUnlock(cmd: CommandMessage): Promise<CommandResult> {
    const res = await this.deviceCtrl.unlock()
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleWipe(cmd: CommandMessage): Promise<CommandResult> {
    const res = await this.deviceCtrl.wipe()
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleReboot(cmd: CommandMessage): Promise<CommandResult> {
    const res = await this.deviceCtrl.reboot()
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleResetPassword(cmd: CommandMessage): Promise<CommandResult> {
    const password = cmd.getString('password')
    if (!password) {
      return CommandResult.failure(cmd.commandId, cmd.action, '缺少password参数')
    }
    const res = await this.deviceCtrl.resetPassword(password)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  // 应用管理处理

  private async handleInstallApp(cmd: CommandMessage): Promise<CommandResult> {
    const apkPath = cmd.getString('apkPath')
    if (!apkPath) {
      return CommandResult.failure(cmd.commandId, cmd.action, '缺少apkPath参数')
    }
    const res = await this.appMgr.install(apkPath)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleUninstallApp(cmd: CommandMessage): Promise<CommandResult> {
    const bundleName = cmd.getString('bundleName')
    if (!bundleName) {
      return CommandResult.failure(cmd.commandId, cmd.action, '缺少bundleName参数')
    }
    const res = await this.appMgr.uninstall(bundleName)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleGetAppList(cmd: CommandMessage): Promise<CommandResult> {
    const res = await this.appMgr.getAppList()
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message, { apps: res.apps })
  }

  // 限制策略处理

  private async handleDisableWifi(cmd: CommandMessage, disabled: boolean): Promise<CommandResult> {
    const res = await this.restrictMgr.setWifiDisabled(disabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleDisableMobileData(cmd: CommandMessage, disabled: boolean): Promise<CommandResult> {
    const res = await this.restrictMgr.setMobileDataDisabled(disabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleSetGps(cmd: CommandMessage): Promise<CommandResult> {
    const enabled = cmd.getBoolean('enabled', false)
    const res = await this.restrictMgr.setGpsEnabled(enabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleSetBluetooth(cmd: CommandMessage): Promise<CommandResult> {
    const enabled = cmd.getBoolean('enabled', false)
    const res = await this.restrictMgr.setBluetoothDisabled(!enabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleDisableCamera(cmd: CommandMessage, disabled: boolean): Promise<CommandResult> {
    const res = await this.restrictMgr.setCameraDisabled(disabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleDisableMicrophone(cmd: CommandMessage, disabled: boolean): Promise<CommandResult> {
    const res = await this.restrictMgr.setMicrophoneDisabled(disabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleDisableUsbDebug(cmd: CommandMessage, disabled: boolean): Promise<CommandResult> {
    const res = await this.restrictMgr.setUsbDebugDisabled(disabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  private async handleDisableScreenshot(cmd: CommandMessage, disabled: boolean): Promise<CommandResult> {
    const res = await this.restrictMgr.setScreenshotDisabled(disabled)
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message)
  }

  // 信息查询处理

  private async handleGetDeviceInfo(cmd: CommandMessage): Promise<CommandResult> {
    const res = await this.infoQuerier.getDeviceInfo()
    return new CommandResult(cmd.commandId, cmd.action, res.success, res.message, res.data ? { info: res.data } : null)
  }
}
