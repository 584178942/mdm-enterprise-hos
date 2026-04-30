// 推荐的导入方式
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'ConfigStore'
const DOMAIN: number = 0x0001
const PREFERENCES_NAME: string = 'mdm_config'

let prefInstance: preferences.Preferences | null = null
let contextInstance: Context | null = null

const KEY_DEVICE_ID: string = 'device_id'
const KEY_MQTT_SERVER_URI: string = 'mqtt_server_uri'
const KEY_MQTT_USERNAME: string = 'mqtt_username'
const KEY_MQTT_PASSWORD: string = 'mqtt_password'
const KEY_MQTT_CLIENT_ID: string = 'mqtt_client_id'
const KEY_HEARTBEAT_INTERVAL: string = 'heartbeat_interval'
const KEY_LAST_HEARTBEAT_TIME: string = 'last_heartbeat_time'
const KEY_ADMIN_ACTIVATED: string = 'admin_activated'
const KEY_LAST_SYNC_TIME: string = 'last_sync_time'
const KEY_USE_MOCK_MODE: string = 'use_mock_mode'

/**
 * 配置存储管理器
 * 使用Preferences存储键值对配置
 */
export class ConfigStore {
  /**
   * 初始化配置存储
   * @param context 应用上下文
   */
  static async init(context: Context): Promise<void> {
    try {
      contextInstance = context
      prefInstance = await preferences.getPreferences(context, PREFERENCES_NAME)
      hilog.info(DOMAIN, TAG, 'ConfigStore initialized successfully')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize ConfigStore: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 设置配置项
   * @param key 键
   * @param value 值
   */
  static async set(key: string, value: string): Promise<void> {
    if (!prefInstance) {
      hilog.error(DOMAIN, TAG, 'ConfigStore not initialized')
      return
    }
    try {
      await prefInstance.put(key, value)
      await prefInstance.flush()
      hilog.info(DOMAIN, TAG, 'Config set: %{public}s = %{public}s', key, value)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set config: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 获取配置项
   * @param key 键
   * @param def 默认值
   * @returns 配置值
   */
  static async get(key: string, def: string = ''): Promise<string> {
    if (!prefInstance) {
      hilog.error(DOMAIN, TAG, 'ConfigStore not initialized')
      return def
    }
    try {
      const value = await prefInstance.get(key, def)
      if (typeof value === 'string') {
        return value
      }
      return def
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get config: %{public}s', JSON.stringify(err))
      return def
    }
  }

  /**
   * 删除配置项
   * @param key 键
   */
  static async delete(key: string): Promise<void> {
    if (!prefInstance) {
      hilog.error(DOMAIN, TAG, 'ConfigStore not initialized')
      return
    }
    try {
      await prefInstance.delete(key)
      await prefInstance.flush()
      hilog.info(DOMAIN, TAG, 'Config deleted: %{public}s', key)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to delete config: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 获取设备ID
   */
  static async getDeviceId(): Promise<string> {
    let deviceId = await ConfigStore.get(KEY_DEVICE_ID)
    if (!deviceId) {
      // 生成新的设备ID
      deviceId = 'mdm_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 8)
      await ConfigStore.set(KEY_DEVICE_ID, deviceId)
      hilog.info(DOMAIN, TAG, 'Generated new deviceId: %{public}s', deviceId)
    }
    return deviceId
  }

  /**
   * 保存设备ID
   * @param deviceId 设备ID
   */
  static async saveDeviceId(deviceId: string): Promise<void> {
    await ConfigStore.set(KEY_DEVICE_ID, deviceId)
  }

  /**
   * 获取MQTT服务器URI
   */
  static async getMqttServerUri(): Promise<string> {
    return await ConfigStore.get(KEY_MQTT_SERVER_URI, 'tcp://192.168.1.199:1883')
  }

  /**
   * 保存MQTT服务器URI
   */
  static async saveMqttServerUri(uri: string): Promise<void> {
    await ConfigStore.set(KEY_MQTT_SERVER_URI, uri)
  }

  /**
   * 获取MQTT用户名
   */
  static async getMqttUsername(): Promise<string> {
    return await ConfigStore.get(KEY_MQTT_USERNAME, 'admin')
  }

  /**
   * 保存MQTT用户名
   */
  static async saveMqttUsername(username: string): Promise<void> {
    await ConfigStore.set(KEY_MQTT_USERNAME, username)
  }

  /**
   * 获取MQTT密码
   */
  static async getMqttPassword(): Promise<string> {
    return await ConfigStore.get(KEY_MQTT_PASSWORD, 'admin')
  }

  /**
   * 保存MQTT密码
   */
  static async saveMqttPassword(password: string): Promise<void> {
    await ConfigStore.set(KEY_MQTT_PASSWORD, password)
  }

  /**
   * 获取心跳间隔(毫秒)
   */
  static async getHeartbeatInterval(): Promise<number> {
    const interval = await ConfigStore.get(KEY_HEARTBEAT_INTERVAL)
    return interval ? parseInt(interval) : 120000 // 默认2分钟
  }

  /**
   * 保存心跳间隔
   */
  static async saveHeartbeatInterval(interval: number): Promise<void> {
    await ConfigStore.set(KEY_HEARTBEAT_INTERVAL, interval.toString())
  }

  /**
   * 获取最后心跳时间
   */
  static async getLastHeartbeatTime(): Promise<number> {
    const time = await ConfigStore.get(KEY_LAST_HEARTBEAT_TIME)
    return time ? parseInt(time) : 0
  }

  /**
   * 保存最后心跳时间
   */
  static async saveLastHeartbeatTime(time: number): Promise<void> {
    await ConfigStore.set(KEY_LAST_HEARTBEAT_TIME, time.toString())
  }

  /**
   * 检查管理员是否已激活
   */
  static async isAdminActivated(): Promise<boolean> {
    const activated = await ConfigStore.get(KEY_ADMIN_ACTIVATED)
    return activated === 'true'
  }

  /**
   * 保存管理员激活状态
   */
  static async saveAdminActivated(activated: boolean): Promise<void> {
    await ConfigStore.set(KEY_ADMIN_ACTIVATED, activated.toString())
  }

  /**
   * 获取是否使用Mock模式
   */
  static async isMockMode(): Promise<boolean> {
    const mock = await ConfigStore.get(KEY_USE_MOCK_MODE)
    return mock !== 'false' // 默认为true
  }

  /**
   * 保存是否使用Mock模式
   */
  static async saveMockMode(mock: boolean): Promise<void> {
    await ConfigStore.set(KEY_USE_MOCK_MODE, mock.toString())
  }

  /**
   * 获取最后同步时间
   */
  static async getLastSyncTime(): Promise<number> {
    const time = await ConfigStore.get(KEY_LAST_SYNC_TIME)
    return time ? parseInt(time) : 0
  }

  /**
   * 保存最后同步时间
   */
  static async saveLastSyncTime(time: number): Promise<void> {
    await ConfigStore.set(KEY_LAST_SYNC_TIME, time.toString())
  }

  /**
   * 获取所有配置（用于调试）
   */
  static async getAll(): Promise<Record<string, string>> {
    const allKeys: string[] = [
      KEY_DEVICE_ID,
      KEY_MQTT_SERVER_URI,
      KEY_MQTT_USERNAME,
      KEY_MQTT_PASSWORD,
      KEY_MQTT_CLIENT_ID,
      KEY_HEARTBEAT_INTERVAL,
      KEY_LAST_HEARTBEAT_TIME,
      KEY_ADMIN_ACTIVATED,
      KEY_LAST_SYNC_TIME,
      KEY_USE_MOCK_MODE
    ]
    const result: Record<string, string> = {}
    for (const key of allKeys) {
      const value = await ConfigStore.get(key)
      if (value) {
        result[key] = value
      }
    }
    return result
  }

  /**
   * 清除所有配置
   */
  static async clear(): Promise<void> {
    if (!prefInstance) {
      return
    }
    try {
      await prefInstance.clear()
      await prefInstance.flush()
      hilog.info(DOMAIN, TAG, 'ConfigStore cleared')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to clear ConfigStore: %{public}s', JSON.stringify(err))
    }
  }
}
