import connection from '@ohos.net.connection'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'NetworkMonitor'
const DOMAIN = 0x0001

/**
 * 网络类型
 */
export enum NetworkType {
  WIFI = 'WiFi',
  CELLULAR = 'Cellular',
  ETHERNET = 'Ethernet',
  NONE = 'None',
  UNKNOWN = 'Unknown'
}

/**
 * 网络状态信息
 */
export interface NetworkInfo {
  isAvailable: boolean       // 网络是否可用
  networkType: NetworkType   // 网络类型
  isMetered: boolean         // 是否按流量计费
}

/**
 * 网络状态监听器
 */
export type NetworkChangeListener = (info: NetworkInfo) => void

/**
 * 网络监控器
 * 监听网络状态变化
 */
export class NetworkMonitor {
  private listeners: NetworkChangeListener[] = []
  private lastInfo: NetworkInfo | null = null

  /**
   * 获取当前网络信息
   */
  getInfo(): NetworkInfo {
    try {
      const netHandle = connection.getDefaultNetSync()
      const isAvailable = netHandle !== null

      if (!isAvailable) {
        return {
          isAvailable: false,
          networkType: NetworkType.NONE,
          isMetered: false
        }
      }

      // 获取网络类型
      const netCapability = connection.getNetCapabilitiesSync(netHandle)
      let networkType = NetworkType.UNKNOWN

      if (netCapability.netCapabilities.includes(connection.NetCap.NET_CAPABILITY_WIFI)) {
        networkType = NetworkType.WIFI
      } else if (netCapability.netCapabilities.includes(connection.NetCap.NET_CAPABILITY_MOBILE)) {
        networkType = NetworkType.CELLULAR
      } else if (netCapability.netCapabilities.includes(connection.NetCap.NET_CAPABILITY_ETHERNET)) {
        networkType = NetworkType.ETHERNET
      }

      const info: NetworkInfo = {
        isAvailable: true,
        networkType: networkType,
        isMetered: netCapability.isMetered || false
      }

      this.lastInfo = info
      return info
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get network info: %{public}s', JSON.stringify(err))
      return {
        isAvailable: false,
        networkType: NetworkType.NONE,
        isMetered: false
      }
    }
  }

  /**
   * 检查网络是否可用
   */
  isNetworkAvailable(): boolean {
    return this.getInfo().isAvailable
  }

  /**
   * 监听网络状态变化
   * @param listener 监听回调
   */
  onChange(listener: NetworkChangeListener): void {
    this.listeners.push(listener)

    // 立即通知当前状态
    const info = this.getInfo()
    listener(info)

    // 注册网络状态变化回调
    try {
      connection.on('netAvailable', () => {
        hilog.info(DOMAIN, TAG, 'Network available changed')
        this.notifyListeners()
      })

      connection.on('netUnavailable', () => {
        hilog.info(DOMAIN, TAG, 'Network unavailable')
        this.notifyListeners()
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to register network listener: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 取消所有监听
   */
  off(): void {
    try {
      connection.off('netAvailable')
      connection.off('netUnavailable')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to unregister network listener: %{public}s', JSON.stringify(err))
    }
    this.listeners = []
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
        hilog.error(DOMAIN, TAG, 'Network listener error: %{public}s', JSON.stringify(err))
      }
    })
  }

  /**
   * 获取上一次获取的信息
   */
  getLastInfo(): NetworkInfo | null {
    return this.lastInfo
  }
}
