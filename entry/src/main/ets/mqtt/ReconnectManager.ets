import { hilog } from '@kit.PerformanceAnalysisKit'
import { MqttConfig } from './MqttConfig'

const TAG = 'ReconnectManager'
const DOMAIN = 0x0001

/**
 * MQTT重连管理器
 * 根据断开连接时长动态调整重连延迟
 */
export class ReconnectManager {
  private disconnectTime: number = 0  // 断开连接的时间戳
  private reconnectCount: number = 0  // 重连次数

  /**
   * 记录断开连接的时间
   */
  recordDisconnect(): void {
    this.disconnectTime = Date.now()
    this.reconnectCount++
    hilog.info(DOMAIN, TAG, 'Record disconnect at %{public}d, reconnect count: %{public}d',
      this.disconnectTime, this.reconnectCount)
  }

  /**
   * 获取重连延迟时间(毫秒)
   * 根据断开连接时长动态调整:
   * - < 5分钟: 5秒
   * - < 30分钟: 30秒
   * - < 60分钟: 1分钟
   * - < 360分钟: 3分钟
   * - >= 360分钟: 5分钟
   */
  getDelayMs(): number {
    if (this.disconnectTime === 0) {
      // 首次连接，使用快速重连
      return MqttConfig.RECONNECT_FAST
    }

    const minutes = (Date.now() - this.disconnectTime) / 60000

    let delay: number
    if (minutes < 5) {
      delay = MqttConfig.RECONNECT_FAST
    } else if (minutes < 30) {
      delay = MqttConfig.RECONNECT_NORMAL
    } else if (minutes < 60) {
      delay = MqttConfig.RECONNECT_SLOW
    } else if (minutes < 360) {
      delay = MqttConfig.RECONNECT_VERY_SLOW
    } else {
      delay = MqttConfig.RECONNECT_ULTRA_SLOW
    }

    hilog.info(DOMAIN, TAG, 'Get reconnect delay: %{public}dms (disconnected for %{public}f minutes)', delay, minutes)
    return delay
  }

  /**
   * 重置重连管理器
   * 连接成功后调用
   */
  reset(): void {
    const wasCount = this.reconnectCount
    this.disconnectTime = 0
    this.reconnectCount = 0
    hilog.info(DOMAIN, TAG, 'ReconnectManager reset, previous reconnect count: %{public}d', wasCount)
  }

  /**
   * 获取当前重连次数
   */
  getReconnectCount(): number {
    return this.reconnectCount
  }

  /**
   * 获取断开连接时长(毫秒)
   */
  getDisconnectDuration(): number {
    if (this.disconnectTime === 0) {
      return 0
    }
    return Date.now() - this.disconnectTime
  }

  /**
   * 是否应该继续重连
   * @param maxReconnectCount 最大重连次数，0表示无限制
   */
  shouldReconnect(maxReconnectCount: number = 0): boolean {
    if (maxReconnectCount === 0) {
      return true
    }
    return this.reconnectCount < maxReconnectCount
  }
}
