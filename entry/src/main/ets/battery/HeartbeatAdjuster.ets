import { BatteryMonitor, BatteryInfo } from './BatteryMonitor'
import { NetworkMonitor, NetworkInfo, NetworkType } from '../network/NetworkMonitor'
import { MqttConfig } from '../mqtt/MqttConfig'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'HeartbeatAdjuster'
const DOMAIN = 0x0001

/**
 * 心跳间隔模式
 */
export enum HeartbeatMode {
  HIGH_PERFORMANCE = 'high_performance',   // 高性能模式（充电中+电量充足）
  NORMAL = 'normal',                         // 正常模式
  POWER_SAVING = 'power_saving',             // 省电模式
  ULTRA_POWER_SAVING = 'ultra_power_saving'  // 极致省电模式
}

/**
 * 心跳消息结构
 */
interface HeartbeatMsg {
  deviceId: string
  batteryLevel: number
  isCharging: boolean
  isScreenOn: boolean
  networkType: NetworkType
  heartbeatMode: HeartbeatMode
  timestamp: number
}

/**
 * 心跳调整器
 * 根据电池状态、网络状态动态调整心跳间隔
 */
export class HeartbeatAdjuster {
  private batteryMonitor: BatteryMonitor
  private networkMonitor: NetworkMonitor

  constructor() {
    this.batteryMonitor = new BatteryMonitor()
    this.networkMonitor = new NetworkMonitor()
  }

  /**
   * 获取心跳间隔（毫秒）
   * 根据电量、充电状态、屏幕状态动态调整
   */
  getIntervalMs(): number {
    const batteryInfo = this.batteryMonitor.getInfo()
    const networkInfo = this.networkMonitor.getInfo()
    const mode = this.getMode()

    let interval: number

    switch (mode) {
      case HeartbeatMode.HIGH_PERFORMANCE:
        interval = MqttConfig.HEARTBEAT_HIGH_PERFORMANCE // 1分钟
        break
      case HeartbeatMode.NORMAL:
        interval = MqttConfig.HEARTBEAT_NORMAL // 2分钟
        break
      case HeartbeatMode.POWER_SAVING:
        interval = MqttConfig.HEARTBEAT_POWER_SAVING // 5分钟
        break
      case HeartbeatMode.ULTRA_POWER_SAVING:
        interval = MqttConfig.HEARTBEAT_ULTRA_POWER_SAVING // 10分钟
        break
      default:
        interval = MqttConfig.HEARTBEAT_NORMAL
    }

    hilog.info(DOMAIN, TAG, 'Heartbeat interval: %{public}dms (mode: %{public}s)', interval, mode)
    return interval
  }

  /**
   * 获取当前的心跳模式
   */
  getMode(): HeartbeatMode {
    const batteryInfo = this.batteryMonitor.getInfo()

    // 高性能模式：充电中且电量>50%
    if (batteryInfo.isCharging && batteryInfo.batterySOC > 50) {
      return HeartbeatMode.HIGH_PERFORMANCE
    }

    // 极致省电模式：息屏且未充电
    if (!batteryInfo.isScreenOn && !batteryInfo.isCharging) {
      return HeartbeatMode.ULTRA_POWER_SAVING
    }

    // 省电模式：电量<20%且未充电
    if (batteryInfo.batterySOC < 20 && !batteryInfo.isCharging) {
      return HeartbeatMode.POWER_SAVING
    }

    // 正常模式
    return HeartbeatMode.NORMAL
  }

  /**
   * 获取模式描述
   */
  getModeDescription(): string {
    switch (this.getMode()) {
      case HeartbeatMode.HIGH_PERFORMANCE:
        return '高性能模式 (充电中)'
      case HeartbeatMode.NORMAL:
        return '正常模式'
      case HeartbeatMode.POWER_SAVING:
        return '省电模式'
      case HeartbeatMode.ULTRA_POWER_SAVING:
        return '极致省电模式 (息屏)'
      default:
        return '未知模式'
    }
  }

  /**
   * 构建心跳消息
   * @param deviceId 设备ID
   */
  buildHeartbeatMsg(deviceId: string): string {
    const batteryInfo = this.batteryMonitor.getInfo()
    const networkInfo = this.networkMonitor.getInfo()

    const msg: HeartbeatMsg = {
      deviceId: deviceId,
      batteryLevel: batteryInfo.batterySOC,
      isCharging: batteryInfo.isCharging,
      isScreenOn: batteryInfo.isScreenOn,
      networkType: networkInfo.networkType,
      heartbeatMode: this.getMode(),
      timestamp: Date.now()
    }

    hilog.info(DOMAIN, TAG, 'Building heartbeat: %{public}s', JSON.stringify(msg))
    return JSON.stringify(msg)
  }

  /**
   * 获取电池监控器
   */
  getBatteryMonitor(): BatteryMonitor {
    return this.batteryMonitor
  }

  /**
   * 获取网络监控器
   */
  getNetworkMonitor(): NetworkMonitor {
    return this.networkMonitor
  }

  /**
   * 获取电池信息
   */
  getBatteryInfo(): BatteryInfo {
    return this.batteryMonitor.getInfo()
  }

  /**
   * 获取网络信息
   */
  getNetworkInfo(): NetworkInfo {
    return this.networkMonitor.getInfo()
  }
}
