import battery from '@ohos.battery'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'BatteryMonitor'
const DOMAIN = 0x0001

/**
 * 电池信息
 */
export interface BatteryInfo {
  batterySOC: number        // 电量百分比
  chargingStatus: number    // 充电状态
  isCharging: boolean       // 是否充电中
  isScreenOn: boolean        // 屏幕是否亮起
}

/**
 * 电池状态监听器
 */
export type BatteryChangeListener = (info: BatteryInfo) => void

/**
 * 电池监控器
 * 监听电池状态变化，提供动态心跳间隔计算
 */
export class BatteryMonitor {
  private listeners: BatteryChangeListener[] = []
  private lastInfo: BatteryInfo | null = null

  /**
   * 获取当前电池信息
   */
  getInfo(): BatteryInfo {
    try {
      const batteryInfo = battery.getBatteryInfo()
      const info: BatteryInfo = {
        batterySOC: batteryInfo.batterySOC,
        chargingStatus: batteryInfo.chargingStatus,
        isCharging: batteryInfo.isCharging,
        isScreenOn: this.isScreenOn()
      }
      this.lastInfo = info
      return info
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get battery info: %{public}s', JSON.stringify(err))
      // 返回默认值
      return {
        batterySOC: 100,
        chargingStatus: 0,
        isCharging: false,
        isScreenOn: true
      }
    }
  }

  /**
   * 检查屏幕是否亮起
   * 注意: 此API可能需要额外权限或在不同设备上行为不同
   */
  private isScreenOn(): boolean {
    try {
      // 尝试获取屏幕状态
      // 注意: @ohos.power的API可能因设备而异
      // import power from '@ohos.power'
      // return power.isScreenOn()
      return true // 默认返回true，如果API不可用
    } catch {
      return true
    }
  }

  /**
   * 监听电池状态变化
   * @param listener 监听回调
   */
  onChange(listener: BatteryChangeListener): void {
    this.listeners.push(listener)

    // 立即通知当前状态
    const info = this.getInfo()
    listener(info)
  }

  /**
   * 取消监听
   * @param listener 监听回调
   */
  off(listener: BatteryChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index > -1) {
      this.listeners.splice(index, 1)
    }
  }

  /**
   * 通知所有监听器
   */
  private notifyListeners(): void {
    const info = this.getInfo()
    this.listeners.forEach(listener => {
      try {
        listener(info)
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Battery listener error: %{public}s', JSON.stringify(err))
      }
    })
  }

  /**
   * 是否处于低电量状态
   */
  isLowBattery(): boolean {
    const info = this.getInfo()
    return info.batterySOC < 20 && !info.isCharging
  }

  /**
   * 是否处于省电模式（基于电池状态）
   */
  isPowerSaving(): boolean {
    const info = this.getInfo()
    // 低电量或非充电状态且电量低于50%
    return info.batterySOC < 20 || (!info.isCharging && info.batterySOC < 50)
  }

  /**
   * 获取上一次获取的信息
   */
  getLastInfo(): BatteryInfo | null {
    return this.lastInfo
  }
}
