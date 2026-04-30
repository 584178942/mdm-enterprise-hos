/**
 * 应用信息
 */
export interface AppInfo {
  bundleName: string;
  appName: string;
}

/**
 * 应用列表数据
 */
export interface AppListData {
  apps: Array<AppInfo>;
}

/**
 * 设备详细信息
 */
export interface DeviceInfoDetail {
  deviceId: string;
  manufacturer: string;
  model: string;
  deviceName: string;
  osVersion: string;
  sdkApiVersion: string;
  batteryLevel: number;
  isCharging: boolean;
  networkType: string;
  isScreenOn: boolean;
  lastOnlineTime: number;
}

/**
 * 设备信息数据
 */
export interface DeviceInfoData {
  info: DeviceInfoDetail;
}

/**
 * 原始 JSON 解析结果接口（用于 fromJson 方法）
 */
interface RawCommandResult {
  commandId?: string;
  action?: string;
  success?: boolean;
  message?: string;
  data?: object | null;   // 注意：不能使用 any 或 Record
  timestamp?: number;
}

/**
 * 命令结果类
 * 封装命令执行结果，用于 MQTT 上报
 */
export class CommandResult {
  /** 命令唯一标识 */
  commandId: string = '';
  /** 命令动作 */
  action: string = '';
  /** 是否成功 */
  success: boolean = false;
  /** 结果消息 */
  message: string = '';
  /** 附加数据（任意 JSON 对象，无索引签名） */
  data: object | null = null;
  /** 时间戳 */
  timestamp: number = 0;

  /**
   * 构造函数
   * @param commandId 命令ID
   * @param action 命令动作
   * @param success 是否成功
   * @param message 结果消息
   * @param data 附加数据
   */
  constructor(
    commandId: string = '',
    action: string = '',
    success: boolean = false,
    message: string = '',
    data: object | null = null
  ) {
    this.commandId = commandId;
    this.action = action;
    this.success = success;
    this.message = message;
    this.data = data;
    this.timestamp = Date.now();
  }

  /**
   * 创建成功结果
   * @param cmdId 命令ID
   * @param action 命令动作
   * @param msg 结果消息
   * @param data 附加数据
   */
  static success(cmdId: string, action: string, msg: string = '执行成功', data?: object): CommandResult {
    return new CommandResult(cmdId, action, true, msg, data ?? null);
  }

  /**
   * 创建失败结果
   * @param cmdId 命令ID
   * @param action 命令动作
   * @param msg 错误消息
   */
  static failure(cmdId: string, action: string, msg: string): CommandResult {
    return new CommandResult(cmdId, action, false, msg, null);
  }

  /**
   * 转换为 JSON 字符串
   */
  toJson(): string {
    return JSON.stringify({
      commandId: this.commandId,
      action: this.action,
      success: this.success,
      message: this.message,
      timestamp: this.timestamp,
      data: this.data
    });
  }

  /**
   * 从 JSON 字符串解析
   * @param json JSON 字符串
   */
  static fromJson(json: string): CommandResult | null {
    try {
      const obj = JSON.parse(json) as RawCommandResult;
      const result = new CommandResult();
      // 使用空值合并运算符（若环境不支持可改为三元表达式）
      result.commandId = obj.commandId ?? '';
      result.action = obj.action ?? '';
      result.success = obj.success ?? false;
      result.message = obj.message ?? '';
      result.data = obj.data ?? null;
      result.timestamp = obj.timestamp ?? Date.now();
      return result;
    } catch {
      return null;
    }
  }

  /**
   * 转换为字符串（用于调试）
   */
  toString(): string {
    return `CommandResult(commandId=${this.commandId}, action=${this.action}, success=${this.success}, message=${this.message})`;
  }
}