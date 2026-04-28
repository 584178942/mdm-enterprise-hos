/**
 * MQTT配置参数
 * 包含连接服务器、心跳、重连等配置
 */

// 服务器配置
const SERVER_URI = 'tcp://192.168.1.199:1883'
const CLIENT_ID_PREFIX = 'mdm_siyu_'

// 连接配置
const CONNECTION_TIMEOUT = 30      // 秒
const KEEP_ALIVE_INTERVAL = 60     // 秒
const CLEAN_SESSION = true
const AUTO_RECONNECT = true

// 认证配置
const USERNAME = 'admin'
const PASSWORD = 'admin'

// 遗嘱消息配置
const WILL_TOPIC = 'mdm/report'
const WILL_QOS = 1
const WILL_RETAINED = true

// QoS配置
const PUBLISH_QOS = 1
const SUBSCRIBE_QOS = 1

// 心跳间隔配置(毫秒)
const HEARTBEAT_HIGH_PERFORMANCE = 60000    // 1分钟 - 充电中且电量>50%
const HEARTBEAT_NORMAL = 120000           // 2分钟 - 正常状态
const HEARTBEAT_POWER_SAVING = 300000      // 5分钟 - 电量<20%且未充电
const HEARTBEAT_ULTRA_POWER_SAVING = 600000 // 10分钟 - 息屏且未充电

// 重连延迟配置(毫秒)
const RECONNECT_FAST = 5000        // 5秒 - 断开<5分钟
const RECONNECT_NORMAL = 30000     // 30秒 - 断开<30分钟
const RECONNECT_SLOW = 60000       // 1分钟 - 断开<60分钟
const RECONNECT_VERY_SLOW = 180000 // 3分钟 - 断开<360分钟
const RECONNECT_ULTRA_SLOW = 300000 // 5分钟 - 断开>=360分钟

// MQTT主题
const TOPIC_COMMAND = 'mdm/{deviceId}'           // 接收命令
const TOPIC_CONFIG = 'device/config/{deviceId}'  // 接收配置
const TOPIC_REPORT = 'mdm/report'                // 遗嘱消息
const TOPIC_RESULT = 'mdm/command/{deviceId}'    // 命令结果
const TOPIC_HEARTBEAT = 'mdm/{deviceId}/heartbeat'  // 心跳
const TOPIC_ALERT = 'mdm/{deviceId}/alert'       // 告警

export class MqttConfig {
  // 导出配置常量
  static readonly SERVER_URI = SERVER_URI
  static readonly CLIENT_ID_PREFIX = CLIENT_ID_PREFIX
  static readonly CONNECTION_TIMEOUT = CONNECTION_TIMEOUT
  static readonly KEEP_ALIVE_INTERVAL = KEEP_ALIVE_INTERVAL
  static readonly CLEAN_SESSION = CLEAN_SESSION
  static readonly AUTO_RECONNECT = AUTO_RECONNECT
  static readonly USERNAME = USERNAME
  static readonly PASSWORD = PASSWORD
  static readonly WILL_TOPIC = WILL_TOPIC
  static readonly WILL_QOS = WILL_QOS
  static readonly WILL_RETAINED = WILL_RETAINED
  static readonly PUBLISH_QOS = PUBLISH_QOS
  static readonly SUBSCRIBE_QOS = SUBSCRIBE_QOS
  static readonly HEARTBEAT_HIGH_PERFORMANCE = HEARTBEAT_HIGH_PERFORMANCE
  static readonly HEARTBEAT_NORMAL = HEARTBEAT_NORMAL
  static readonly HEARTBEAT_POWER_SAVING = HEARTBEAT_POWER_SAVING
  static readonly HEARTBEAT_ULTRA_POWER_SAVING = HEARTBEAT_ULTRA_POWER_SAVING
  static readonly RECONNECT_FAST = RECONNECT_FAST
  static readonly RECONNECT_NORMAL = RECONNECT_NORMAL
  static readonly RECONNECT_SLOW = RECONNECT_SLOW
  static readonly RECONNECT_VERY_SLOW = RECONNECT_VERY_SLOW
  static readonly RECONNECT_ULTRA_SLOW = RECONNECT_ULTRA_SLOW
  static readonly TOPIC_COMMAND = TOPIC_COMMAND
  static readonly TOPIC_CONFIG = TOPIC_CONFIG
  static readonly TOPIC_REPORT = TOPIC_REPORT
  static readonly TOPIC_RESULT = TOPIC_RESULT
  static readonly TOPIC_HEARTBEAT = TOPIC_HEARTBEAT
  static readonly TOPIC_ALERT = TOPIC_ALERT

  /**
   * 获取设备命令主题
   * @param deviceId 设备ID
   */
  static getCommandTopic(deviceId: string): string {
    return TOPIC_COMMAND.replace('{deviceId}', deviceId)
  }

  /**
   * 获取设备配置主题
   * @param deviceId 设备ID
   */
  static getConfigTopic(deviceId: string): string {
    return TOPIC_CONFIG.replace('{deviceId}', deviceId)
  }

  /**
   * 获取设备结果主题
   * @param deviceId 设备ID
   */
  static getResultTopic(deviceId: string): string {
    return TOPIC_RESULT.replace('{deviceId}', deviceId)
  }

  /**
   * 获取设备心跳主题
   * @param deviceId 设备ID
   */
  static getHeartbeatTopic(deviceId: string): string {
    return TOPIC_HEARTBEAT.replace('{deviceId}', deviceId)
  }

  /**
   * 获取设备告警主题
   * @param deviceId 设备ID
   */
  static getAlertTopic(deviceId: string): string {
    return TOPIC_ALERT.replace('{deviceId}', deviceId)
  }

  /**
   * 生成客户端ID
   * @param deviceId 设备ID
   */
  static generateClientId(deviceId: string): string {
    return CLIENT_ID_PREFIX + deviceId
  }
}
