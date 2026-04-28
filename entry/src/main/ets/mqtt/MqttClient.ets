import mqtt from '@ohos/mqtt'
import { MqttConfig } from './MqttConfig'
import { ReconnectManager } from './ReconnectManager'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'MqttClientManager'
const DOMAIN = 0x0001

/**
 * MQTT连接状态
 */
export enum MqttConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  RECONNECTING = 'reconnecting',
  ERROR = 'error'
}

/**
 * MQTT客户端选项
 */
interface MqttClientOptions {
  clientId: string
  cleanSession: boolean
  keepAlive: number
}

/**
 * MQTT遗嘱消息选项
 */
interface WillOptions {
  topic: string
  payload: string
  qos: number
  retained: boolean
}

/**
 * MQTT连接选项
 */
interface ConnectOptions {
  username: string
  password: string
  connectTimeout: number
  reconnectPeriod: number
  will: WillOptions
}

/**
 * 命令数据接口
 */
interface CommandData {
  [key: string]: string | number | boolean | object | null
}

/**
 * MQTT客户端管理器
 * 负责MQTT连接、订阅、发布、重连等操作
 */
export class MqttClientManager {
  private client: mqtt.MqttClient | null = null
  private deviceId: string = ''
  private connectionState: MqttConnectionState = MqttConnectionState.DISCONNECTED
  private reconnectManager: ReconnectManager = new ReconnectManager()
  private reconnectTimer: number | null = null

  // 监听器
  private connectionListeners: Array<(state: MqttConnectionState) => void> = []
  private messageListeners: Array<(topic: string, payload: string) => void> = []

  /**
   * 初始化MQTT客户端
   * @param deviceId 设备唯一标识
   */
  initialize(deviceId: string): void {
    this.deviceId = deviceId
    hilog.info(DOMAIN, TAG, 'Initializing MQTT client for device: %{public}s', deviceId)

    // 创建MQTT客户端
    // 注意: 实际API可能因版本而异，这里使用常见写法
    try {
      const clientId = MqttConfig.generateClientId(deviceId)
      const options: MqttClientOptions = {
        clientId: clientId,
        cleanSession: MqttConfig.CLEAN_SESSION,
        keepAlive: MqttConfig.KEEP_ALIVE_INTERVAL
      }
      this.client = mqtt.createMqttClient(MqttConfig.SERVER_URI, options)

      // 设置事件监听
      this.setupEventHandlers()
      hilog.info(DOMAIN, TAG, 'MQTT client created successfully')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to create MQTT client: %{public}s', JSON.stringify(err))
      this.connectionState = MqttConnectionState.ERROR
      this.notifyConnectionListeners()
    }
  }

  /**
   * 设置事件处理器
   */
  private setupEventHandlers(): void {
    if (!this.client) return

    // 连接成功
    this.client.on('connect', () => {
      hilog.info(DOMAIN, TAG, 'MQTT connected')
      this.connectionState = MqttConnectionState.CONNECTED
      this.reconnectManager.reset()
      this.notifyConnectionListeners()
      // 订阅默认主题
      this.subscribeDefaultTopics()
    })

    // 连接关闭
    this.client.on('close', () => {
      hilog.warn(DOMAIN, TAG, 'MQTT connection closed')
      this.connectionState = MqttConnectionState.DISCONNECTED
      this.reconnectManager.recordDisconnect()
      this.notifyConnectionListeners()
    })

    // 连接错误
    this.client.on('error', (err: Error) => {
      hilog.error(DOMAIN, TAG, 'MQTT error: %{public}s', JSON.stringify(err))
      this.connectionState = MqttConnectionState.ERROR
      this.notifyConnectionListeners()
    })

    // 消息到达
    this.client.on('message', (topic: string, payload: string) => {
      hilog.info(DOMAIN, TAG, 'MQTT message received: %{public}s', topic)
      this.notifyMessageListeners(topic, payload)
    })

    // _disconnect事件(某些客户端实现)
    this.client.on('disconnect', () => {
      hilog.warn(DOMAIN, TAG, 'MQTT disconnected event')
      this.connectionState = MqttConnectionState.DISCONNECTED
      this.reconnectManager.recordDisconnect()
      this.notifyConnectionListeners()
    })
  }

  /**
   * 订阅默认主题
   */
  private subscribeDefaultTopics(): void {
    const commandTopic = MqttConfig.getCommandTopic(this.deviceId)
    const configTopic = MqttConfig.getConfigTopic(this.deviceId)

    this.subscribe(commandTopic, MqttConfig.SUBSCRIBE_QOS)
    this.subscribe(configTopic, MqttConfig.SUBSCRIBE_QOS)

    hilog.info(DOMAIN, TAG, 'Subscribed to default topics: %{public}s, %{public}s', commandTopic, configTopic)
  }

  /**
   * 连接到MQTT服务器
   */
  connect(): void {
    if (!this.client) {
      hilog.error(DOMAIN, TAG, 'MQTT client not initialized')
      return
    }

    if (this.connectionState === MqttConnectionState.CONNECTING) {
      hilog.warn(DOMAIN, TAG, 'MQTT already connecting')
      return
    }

    hilog.info(DOMAIN, TAG, 'Connecting to MQTT server: %{public}s', MqttConfig.SERVER_URI)
    this.connectionState = MqttConnectionState.CONNECTING
    this.notifyConnectionListeners()

    try {
      const willPayload: WillOptions = {
        topic: MqttConfig.WILL_TOPIC,
        payload: JSON.stringify({
          action: 'offline',
          deviceId: this.deviceId,
          timestamp: Date.now()
        }),
        qos: MqttConfig.WILL_QOS,
        retained: MqttConfig.WILL_RETAINED
      }
      const connectOptions: ConnectOptions = {
        username: MqttConfig.USERNAME,
        password: MqttConfig.PASSWORD,
        connectTimeout: MqttConfig.CONNECTION_TIMEOUT * 1000,
        reconnectPeriod: 0, // 我们使用自己的重连逻辑
        will: willPayload
      }
      this.client.connect(connectOptions)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'MQTT connect error: %{public}s', JSON.stringify(err))
      this.connectionState = MqttConnectionState.ERROR
      this.scheduleReconnect()
      this.notifyConnectionListeners()
    }
  }

  /**
   * 断开连接
   */
  disconnect(): void {
    hilog.info(DOMAIN, TAG, 'Disconnecting MQTT')
    this.cancelReconnect()
    this.reconnectManager.reset()

    if (this.client) {
      try {
        this.client.disconnect()
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'MQTT disconnect error: %{public}s', JSON.stringify(err))
      }
    }

    this.connectionState = MqttConnectionState.DISCONNECTED
    this.notifyConnectionListeners()
  }

  /**
   * 订阅主题
   * @param topic 主题名
   * @param qos 服务质量等级
   */
  subscribe(topic: string, qos: number = MqttConfig.SUBSCRIBE_QOS): void {
    if (!this.client || !this.isConnected()) {
      hilog.error(DOMAIN, TAG, 'Cannot subscribe: client not connected')
      return
    }

    try {
      this.client.subscribe(topic, qos)
      hilog.info(DOMAIN, TAG, 'Subscribed to topic: %{public}s (QoS: %{public}d)', topic, qos)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Subscribe error: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 取消订阅主题
   * @param topic 主题名
   */
  unsubscribe(topic: string): void {
    if (!this.client) return

    try {
      this.client.unsubscribe(topic)
      hilog.info(DOMAIN, TAG, 'Unsubscribed from topic: %{public}s', topic)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Unsubscribe error: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 发布消息
   * @param topic 主题名
   * @param message 消息内容
   * @param qos 服务质量等级
   * @returns 是否发送成功
   */
  publish(topic: string, message: string, qos: number = MqttConfig.PUBLISH_QOS): boolean {
    if (!this.client || !this.isConnected()) {
      hilog.error(DOMAIN, TAG, 'Cannot publish: client not connected')
      return false
    }

    try {
      this.client.publish(topic, message, qos)
      hilog.info(DOMAIN, TAG, 'Published to topic: %{public}s', topic)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Publish error: %{public}s', JSON.stringify(err))
      return false
    }
  }

  /**
   * 发布命令结果
   * @param commandId 命令ID
   * @param action 命令动作
   * @param success 是否成功
   * @param message 结果消息
   * @param data 附加数据
   */
  publishCommandResult(commandId: string, action: string, success: boolean, message: string, data?: CommandData): boolean {
    const resultTopic = MqttConfig.getResultTopic(this.deviceId)
    const payload = JSON.stringify({
      commandId,
      action,
      success,
      message,
      timestamp: Date.now(),
      data: data || {}
    })
    return this.publish(resultTopic, payload, MqttConfig.PUBLISH_QOS)
  }

  /**
   * 发布心跳
   * @param batteryLevel 电量
   * @param isCharging 是否充电
   * @param isScreenOn 屏幕是否亮起
   * @param networkType 网络类型
   */
  publishHeartbeat(batteryLevel: number, isCharging: boolean, isScreenOn: boolean, networkType: string): boolean {
    const heartbeatTopic = MqttConfig.getHeartbeatTopic(this.deviceId)
    const payload = JSON.stringify({
      deviceId: this.deviceId,
      batteryLevel,
      isCharging,
      isScreenOn,
      networkType,
      timestamp: Date.now()
    })
    return this.publish(heartbeatTopic, payload, 0) // 心跳使用QoS 0
  }

  /**
   * 发布告警
   * @param alertType 告警类型
   * @param alertMessage 告警消息
   * @param data 附加数据
   */
  publishAlert(alertType: string, alertMessage: string, data?: CommandData): boolean {
    const alertTopic = MqttConfig.getAlertTopic(this.deviceId)
    const payload = JSON.stringify({
      deviceId: this.deviceId,
      alertType,
      alertMessage,
      timestamp: Date.now(),
      data: data || {}
    })
    return this.publish(alertTopic, payload, MqttConfig.PUBLISH_QOS)
  }

  /**
   * 是否已连接
   */
  isConnected(): boolean {
    return this.connectionState === MqttConnectionState.CONNECTED
  }

  /**
   * 获取连接状态
   */
  getConnectionState(): MqttConnectionState {
    return this.connectionState
  }

  /**
   * 获取设备ID
   */
  getDeviceId(): string {
    return this.deviceId
  }

  /**
   * 添加连接状态监听器
   * @param listener 监听回调
   */
  addConnectionListener(listener: (state: MqttConnectionState) => void): void {
    this.connectionListeners.push(listener)
  }

  /**
   * 添加消息监听器
   * @param listener 监听回调
   */
  addMessageListener(listener: (topic: string, payload: string) => void): void {
    this.messageListeners.push(listener)
  }

  /**
   * 移除连接状态监听器
   * @param listener 监听回调
   */
  removeConnectionListener(listener: (state: MqttConnectionState) => void): void {
    const index = this.connectionListeners.indexOf(listener)
    if (index > -1) {
      this.connectionListeners.splice(index, 1)
    }
  }

  /**
   * 移除消息监听器
   * @param listener 监听回调
   */
  removeMessageListener(listener: (topic: string, payload: string) => void): void {
    const index = this.messageListeners.indexOf(listener)
    if (index > -1) {
      this.messageListeners.splice(index, 1)
    }
  }

  /**
   * 通知连接状态变化
   */
  private notifyConnectionListeners(): void {
    this.connectionListeners.forEach(listener => {
      try {
        listener(this.connectionState)
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Connection listener error: %{public}s', JSON.stringify(err))
      }
    })
  }

  /**
   * 通知消息到达
   */
  private notifyMessageListeners(topic: string, payload: string): void {
    this.messageListeners.forEach(listener => {
      try {
        listener(topic, payload)
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Message listener error: %{public}s', JSON.stringify(err))
      }
    })
  }

  /**
   * 计划重连
   */
  private scheduleReconnect(): void {
    this.cancelReconnect()

    if (!this.reconnectManager.shouldReconnect(0)) {
      hilog.warn(DOMAIN, TAG, 'Max reconnect count reached, stop reconnecting')
      return
    }

    const delay = this.reconnectManager.getDelayMs()
    hilog.info(DOMAIN, TAG, 'Scheduling reconnect in %{public}d ms', delay)

    this.connectionState = MqttConnectionState.RECONNECTING
    this.notifyConnectionListeners()

    this.reconnectTimer = setTimeout(() => {
      hilog.info(DOMAIN, TAG, 'Attempting reconnect...')
      this.connect()
    }, delay)
  }

  /**
   * 取消重连计划
   */
  private cancelReconnect(): void {
    if (this.reconnectTimer !== null) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
  }

  /**
   * 释放资源
   */
  release(): void {
    hilog.info(DOMAIN, TAG, 'Releasing MQTT client')
    this.cancelReconnect()
    this.connectionListeners = []
    this.messageListeners = []

    if (this.client) {
      try {
        this.client.disconnect()
        // 某些客户端可能需要销毁
        // this.client.destroy?.()
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Release error: %{public}s', JSON.stringify(err))
      }
      this.client = null
    }

    this.connectionState = MqttConnectionState.DISCONNECTED
  }
}
