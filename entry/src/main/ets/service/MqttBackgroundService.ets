import backgroundTaskManager from '@ohos.ability.backgroundTaskManager'
import { BusinessError } from '@ohos.base'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MqttClientManager, MqttConnectionState } from '../mqtt/MqttClient'
import { CommandHandler } from '../command/CommandHandler'
import { CommandMessage } from '../command/CommandParser'
import { HeartbeatAdjuster } from '../battery/HeartbeatAdjuster'
import { ConfigStore } from '../storage/ConfigStore'

const TAG = 'MqttBackgroundService'
const DOMAIN = 0x0001
const BACKGROUND_TASK_ID = 10001

/**
 * MQTT后台服务
 * 负责维护MQTT长连接、处理命令、心跳等后台任务
 */
export class MqttBackgroundService {
  private mqttClient: MqttClientManager | null = null
  private commandHandler: CommandHandler
  private heartbeatAdjuster: HeartbeatAdjuster
  private heartbeatTimer: number | null = null
  private isRunning: boolean = false
  private backgroundTaskId: number = 0

  constructor() {
    this.commandHandler = new CommandHandler()
    this.heartbeatAdjuster = new HeartbeatAdjuster()
  }

  /**
   * 启动后台服务
   * @param context 应用上下文
   */
  async start(context: Context): Promise<void> {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'Service already running')
      return
    }

    hilog.info(DOMAIN, TAG, 'Starting MQTT background service')

    try {
      // 初始化配置存储
      await ConfigStore.init(context)

      // 初始化MQTT客户端
      const deviceId = await ConfigStore.getDeviceId()
      this.mqttClient = new MqttClientManager()
      this.mqttClient.initialize(deviceId)

      // 设置连接状态监听
      this.mqttClient.addConnectionListener((state) => {
        this.onConnectionStateChanged(state)
      })

      // 设置消息监听
      this.mqttClient.addMessageListener((topic, payload) => {
        this.onMessageReceived(topic, payload)
      })

      // 申请后台任务
      this.requestBackgroundTask()

      // 启动心跳
      this.startHeartbeat()

      // 连接MQTT服务器
      this.mqttClient.connect()

      this.isRunning = true
      hilog.info(DOMAIN, TAG, 'MQTT background service started')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to start service: %{public}s', JSON.stringify(err))
      throw
    }
  }

  /**
   * 停止后台服务
   */
  stop(): void {
    if (!this.isRunning) {
      return
    }

    hilog.info(DOMAIN, TAG, 'Stopping MQTT background service')

    // 停止心跳
    this.stopHeartbeat()

    // 断开MQTT连接
    if (this.mqttClient) {
      this.mqttClient.disconnect()
      this.mqttClient.release()
      this.mqttClient = null
    }

    // 取消后台任务
    this.cancelBackgroundTask()

    this.isRunning = false
    hilog.info(DOMAIN, TAG, 'MQTT background service stopped')
  }

  /**
   * 申请后台任务
   */
  private requestBackgroundTask(): void {
    try {
      this.backgroundTaskId = backgroundTaskManager.requestBackgroundRunningprivilege(
        (err: BusinessError) => {
          if (err) {
            hilog.error(DOMAIN, TAG, 'Request background task failed: %{public}s', err.message)
          } else {
            hilog.info(DOMAIN, TAG, 'Background task granted')
          }
        }
      )
      hilog.info(DOMAIN, TAG, 'Background task ID: %{public}d', this.backgroundTaskId)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Request background task error: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 取消后台任务
   */
  private cancelBackgroundTask(): void {
    if (this.backgroundTaskId !== 0) {
      try {
        backgroundTaskManager.cancelBackgroundRunningprivilege(this.backgroundTaskId)
        hilog.info(DOMAIN, TAG, 'Background task cancelled')
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Cancel background task error: %{public}s', JSON.stringify(err))
      }
    }
  }

  /**
   * 连接状态变化处理
   */
  private onConnectionStateChanged(state: MqttConnectionState): void {
    hilog.info(DOMAIN, TAG, 'Connection state changed: %{public}s', state)

    switch (state) {
      case MqttConnectionState.CONNECTED:
        hilog.info(DOMAIN, TAG, 'MQTT connected successfully')
        // 保存最后心跳时间
        ConfigStore.saveLastHeartbeatTime(Date.now())
        break
      case MqttConnectionState.DISCONNECTED:
        hilog.warn(DOMAIN, TAG, 'MQTT disconnected')
        break
      case MqttConnectionState.RECONNECTING:
        hilog.info(DOMAIN, TAG, 'MQTT reconnecting...')
        break
      case MqttConnectionState.ERROR:
        hilog.error(DOMAIN, TAG, 'MQTT error')
        break
    }
  }

  /**
   * 收到消息处理
   */
  private async onMessageReceived(topic: string, payload: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Message received on topic: %{public}s', topic)

    try {
      // 解析命令
      const cmd = CommandMessage.fromJson(payload)
      if (!cmd) {
        hilog.error(DOMAIN, TAG, 'Failed to parse command message')
        return
      }

      // 处理命令
      const result = await this.commandHandler.handle(cmd)

      // 上报命令结果
      if (this.mqttClient) {
        this.mqttClient.publishCommandResult(
          result.commandId,
          result.action,
          result.success,
          result.message,
          result.data
        )
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Error handling message: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 启动心跳
   */
  private startHeartbeat(): void {
    if (this.heartbeatTimer !== null) {
      return
    }

    hilog.info(DOMAIN, TAG, 'Starting heartbeat')

    const sendHeartbeat = () => {
      if (this.mqttClient && this.mqttClient.isConnected()) {
        const msg = this.heartbeatAdjuster.buildHeartbeatMsg(this.mqttClient.getDeviceId())
        this.mqttClient.publishHeartbeat(
          this.heartbeatAdjuster.getBatteryInfo().batterySOC,
          this.heartbeatAdjuster.getBatteryInfo().isCharging,
          this.heartbeatAdjuster.getBatteryInfo().isScreenOn,
          this.heartbeatAdjuster.getNetworkInfo().networkType
        )
        hilog.info(DOMAIN, TAG, 'Heartbeat sent')
      }

      // 计划下一次心跳
      const interval = this.heartbeatAdjuster.getIntervalMs()
      this.heartbeatTimer = setTimeout(sendHeartbeat, interval)
    }

    // 立即发送第一次心跳
    sendHeartbeat()
  }

  /**
   * 停止心跳
   */
  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== null) {
      clearTimeout(this.heartbeatTimer)
      this.heartbeatTimer = null
      hilog.info(DOMAIN, TAG, 'Heartbeat stopped')
    }
  }

  /**
   * 获取服务运行状态
   */
  isServiceRunning(): boolean {
    return this.isRunning
  }

  /**
   * 获取MQTT连接状态
   */
  getConnectionState(): MqttConnectionState | null {
    return this.mqttClient?.getConnectionState() || null
  }

  /**
   * 获取心跳调整器
   */
  getHeartbeatAdjuster(): HeartbeatAdjuster {
    return this.heartbeatAdjuster
  }
}

// 单例实例
let serviceInstance: MqttBackgroundService | null = null

/**
 * 获取后台服务单例
 */
export function getMqttBackgroundService(): MqttBackgroundService {
  if (!serviceInstance) {
    serviceInstance = new MqttBackgroundService()
  }
  return serviceInstance
}
