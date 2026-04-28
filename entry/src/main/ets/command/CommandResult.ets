/**
 * 命令结果数据接口
 */
interface ResultData {
  [key: string]: string | number | boolean | object | null
}

/**
 * 命令结果类
 * 封装命令执行结果，用于MQTT上报
 */
export class CommandResult {
  /** 命令唯一标识 */
  commandId: string = ''
  /** 命令动作 */
  action: string = ''
  /** 是否成功 */
  success: boolean = false
  /** 结果消息 */
  message: string = ''
  /** 附加数据 */
  data: ResultData | null = null
  /** 时间戳 */
  timestamp: number = 0

  constructor(
    commandId: string = '',
    action: string = '',
    success: boolean = false,
    message: string = '',
    data: ResultData | null = null
  ) {
    this.commandId = commandId
    this.action = action
    this.success = success
    this.message = message
    this.data = data
    this.timestamp = Date.now()
  }

  /**
   * 创建成功结果
   * @param cmdId 命令ID
   * @param action 命令动作
   * @param msg 结果消息
   * @param data 附加数据
   */
  static success(cmdId: string, action: string, msg: string = '执行成功', data?: ResultData): CommandResult {
    return new CommandResult(cmdId, action, true, msg, data || null)
  }

  /**
   * 创建失败结果
   * @param cmdId 命令ID
   * @param action 命令动作
   * @param msg 错误消息
   */
  static failure(cmdId: string, action: string, msg: string): CommandResult {
    return new CommandResult(cmdId, action, false, msg, null)
  }

  /**
   * 转换为JSON字符串
   */
  toJson(): string {
    return JSON.stringify({
      commandId: this.commandId,
      action: this.action,
      success: this.success,
      message: this.message,
      timestamp: this.timestamp,
      data: this.data
    })
  }

  /**
   * 从JSON字符串解析
   * @param json JSON字符串
   */
  static fromJson(json: string): CommandResult | null {
    try {
      const obj = JSON.parse(json)
      const result = new CommandResult()
      result.commandId = obj.commandId || ''
      result.action = obj.action || ''
      result.success = obj.success || false
      result.message = obj.message || ''
      result.data = obj.data || null
      result.timestamp = obj.timestamp || Date.now()
      return result
    } catch {
      return null
    }
  }

  /**
   * 转换为字符串（用于调试）
   */
  toString(): string {
    return `CommandResult(commandId=${this.commandId}, action=${this.action}, success=${this.success}, message=${this.message})`
  }
}
