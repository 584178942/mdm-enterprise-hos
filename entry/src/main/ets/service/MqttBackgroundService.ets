import { hilog } from '@kit.PerformanceAnalysisKit'
import { MqttClientManager, MqttConnectionState } from '../mqtt/MqttClient'
import { CommandHandler } from '../command/CommandHandler'
import { CommandMessage } from '../command/CommandParser'
import { HeartbeatAdjuster } from '../battery/HeartbeatAdjuster'
import { ConfigStore } from '../storage/ConfigStore'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'

const TAG: string = 'MqttBackgroundService'
const DOMAIN: number = 0x0001
const BACKGROUND_TASK_ID: number = 10001

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

  async start(context: Context): Promise<void> {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'Service already running')
      return
    }

    hilog.info(DOMAIN, TAG, 'Starting MQTT background service')

    try {
      await ConfigStore.init(context)

      const deviceId: string = await ConfigStore.getDeviceId()
      this.mqttClient = new MqttClientManager()
      this.mqttClient.initialize(deviceId)

      this.mqttClient.addConnectionListener((state: MqttConnectionState) => {
        this.onConnectionStateChanged(state)
      })

      this.mqttClient.addMessageListener((topic: string, payload: string) => {
        this.onMessageReceived(topic, payload)
      })

      this.requestBackgroundTask()
      this.startHeartbeat()
      this.mqttClient.connect()

      this.isRunning = true
      hilog.info(DOMAIN, TAG, 'MQTT background service started')
    } catch (err) {
      const error = err as Error
      hilog.error(DOMAIN, TAG, 'Failed to start service: %{public}s', error.message)
    }
  }

  stop(): void {
    if (!this.isRunning) {
      return
    }

    hilog.info(DOMAIN, TAG, 'Stopping MQTT background service')

    this.stopHeartbeat()

    if (this.mqttClient) {
      this.mqttClient.disconnect()
      this.mqttClient.release()
      this.mqttClient = null
    }

    this.cancelBackgroundTask()

    this.isRunning = false
    hilog.info(DOMAIN, TAG, 'MQTT background service stopped')
  }

  private requestBackgroundTask(): void {
    try {
      const isAllowed: boolean = backgroundTaskManager.requestBackgroundRunning()
      if (isAllowed) {
        hilog.info(DOMAIN, TAG, 'Background task granted')
      } else {
        hilog.warn(DOMAIN, TAG, 'Background task not allowed')
      }
    } catch (err) {
      const error = err as Error
      hilog.error(DOMAIN, TAG, 'Request background task error: %{public}s', error.message)
    }
  }

  private cancelBackgroundTask(): void {
    try {
      backgroundTaskManager.cancelBackgroundRunning()
      hilog.info(DOMAIN, TAG, 'Background task cancelled')
    } catch (err) {
      const error = err as Error
      hilog.error(DOMAIN, TAG, 'Cancel background task error: %{public}s', error.message)
    }
  }

  private onConnectionStateChanged(state: MqttConnectionState): void {
    hilog.info(DOMAIN, TAG, 'Connection state changed: %{public}s', state)

    switch (state) {
      case MqttConnectionState.CONNECTED:
        hilog.info(DOMAIN, TAG, 'MQTT connected successfully')
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

  private async onMessageReceived(topic: string, payload: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Message received on topic: %{public}s', topic)

    try {
      const cmd: CommandMessage | null = CommandMessage.fromJson(payload)
      if (!cmd) {
        hilog.error(DOMAIN, TAG, 'Failed to parse command message')
        return
      }

      const result = await this.commandHandler.handle(cmd)

      if (this.mqttClient) {
        this.mqttClient.publishCommandResult(
          result.commandId,
          result.action,
          result.success,
          result.message,
          result.data as Record<string, Object>
        )
      }
    } catch (err) {
      const error = err as Error
      hilog.error(DOMAIN, TAG, 'Error handling message: %{public}s', error.message)
    }
  }

  private startHeartbeat(): void {
    if (this.heartbeatTimer !== null) {
      return
    }

    hilog.info(DOMAIN, TAG, 'Starting heartbeat')

    const sendHeartbeat = (): void => {
      if (this.mqttClient && this.mqttClient.isConnected()) {
        this.mqttClient.publishHeartbeat(
          this.heartbeatAdjuster.getBatteryInfo().batterySOC,
          this.heartbeatAdjuster.getBatteryInfo().isCharging,
          this.heartbeatAdjuster.getBatteryInfo().isScreenOn,
          this.heartbeatAdjuster.getNetworkInfo().networkType
        )
        hilog.info(DOMAIN, TAG, 'Heartbeat sent')
      }

      const interval: number = this.heartbeatAdjuster.getIntervalMs()
      this.heartbeatTimer = setTimeout(sendHeartbeat, interval)
    }

    sendHeartbeat()
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== null) {
      clearTimeout(this.heartbeatTimer)
      this.heartbeatTimer = null
      hilog.info(DOMAIN, TAG, 'Heartbeat stopped')
    }
  }

  isServiceRunning(): boolean {
    return this.isRunning
  }

  getConnectionState(): MqttConnectionState | null {
    return this.mqttClient?.getConnectionState() || null
  }

  getHeartbeatAdjuster(): HeartbeatAdjuster {
    return this.heartbeatAdjuster
  }
}

let serviceInstance: MqttBackgroundService | null = null

export function getMqttBackgroundService(): MqttBackgroundService {
  if (!serviceInstance) {
    serviceInstance = new MqttBackgroundService()
  }
  return serviceInstance
}
