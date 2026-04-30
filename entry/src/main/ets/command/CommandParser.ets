import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'CommandParser'
const DOMAIN = 0x0001

interface RawCommandMessage {
  commandId: string;
  action: string;
  params?: object;           // 原始 JSON 对象，后续转为 Map
  timestamp?: number;
}
/**
 * 命令消息类
 * 解析和存储MQTT接收到的命令
 */
export class CommandMessage {
  /** 命令唯一标识 */
  commandId: string = ''
  /** 命令动作 */
  action: string = ''
  /** 命令参数 - 使用 Map 替代 Record */
  params: Map<string, string | number | boolean | object | null> | null = null
  /** 时间戳 */
  timestamp: number = 0

  /**
   * 从JSON字符串解析命令
   * @param json JSON字符串
   * @returns 命令消息对象，解析失败返回null
   */
  static fromJson(json: string): CommandMessage | null {
    try {
      const obj = JSON.parse(json) as RawCommandMessage

      if (!obj.commandId || !obj.action) {
        hilog.error(DOMAIN, TAG, 'Missing commandId or action in command')
        return null
      }

      const cmd = new CommandMessage()
      cmd.commandId = obj.commandId as string
      cmd.action = obj.action as string
      // 将普通对象转换为 Map
      if (obj.params && typeof obj.params === 'object') {
        const paramsObj = obj.params;
        const map = new Map<string, string | number | boolean | object | null>()
        Object.keys(obj.params).forEach(key => {
          map.set(key, paramsObj[key])
        })
        cmd.params = map
      } else {
        cmd.params = null
      }
      cmd.timestamp = (obj.timestamp as number) || Date.now()

      hilog.info(DOMAIN, TAG, 'Parsed command: %{public}s, action: %{public}s', cmd.commandId, cmd.action)
      return cmd
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse command: %{public}s', JSON.stringify(err))
      return null
    }
  }

  /**
   * 获取字符串参数
   * @param key 参数键
   * @param def 默认值
   */
  getString(key: string, def: string = ''): string {
    if (!this.params) {
      return def
    }
    const val = this.params.get(key)
    return val !== undefined ? String(val) : def
  }

  /**
   * 获取布尔参数
   * @param key 参数键
   * @param def 默认值
   */
  getBoolean(key: string, def: boolean = false): boolean {
    if (!this.params) {
      return def
    }
    const val = this.params.get(key)
    return val !== undefined ? Boolean(val) : def
  }

  /**
   * 获取数字参数
   * @param key 参数键
   * @param def 默认值
   */
  getNumber(key: string, def: number = 0): number {
    if (!this.params) {
      return def
    }
    const val = this.params.get(key)
    if (val === undefined) {
      return def
    }
    if (typeof val === 'number') {
      return val
    }
    const parsed = parseFloat(String(val))
    return isNaN(parsed) ? def : parsed
  }

  /**
   * 检查参数是否存在
   * @param key 参数键
   */
  hasParam(key: string): boolean {
    return !!this.params && this.params.has(key)
  }

  /**
   * 转换为字符串
   */
  toString(): string {
    return `CommandMessage(commandId=${this.commandId}, action=${this.action}, timestamp=${this.timestamp})`
  }
}
