/**
 * 操作结果接口
 */
export interface OperationResult {
  success: boolean
  message: string
}

/**
 * 设备控制接口
 * 定义设备锁定、解锁、恢复出厂、重启、密码重置等操作
 * Mock和Real实现都需实现此接口
 */
export interface IDeviceController {
  /**
   * 锁定设备
   * @param mainText 主文本（显示在锁屏界面）
   * @param subText 副文本（显示在锁屏界面）
   */
  lock(mainText: string, subText: string): Promise<OperationResult>

  /**
   * 解锁设备
   */
  unlock(): Promise<OperationResult>

  /**
   * 恢复出厂设置
   */
  wipe(): Promise<OperationResult>

  /**
   * 重启设备
   */
  reboot(): Promise<OperationResult>

  /**
   * 重置密码
   * @param password 新密码
   */
  resetPassword(password: string): Promise<OperationResult>
}

/**
 * 设备信息接口
 */
export interface IDeviceInfo {
  deviceId: string
  manufacturer: string
  model: string
  deviceName: string
  osVersion: string
  sdkApiVersion: string
  batteryLevel: number
  isCharging: boolean
  networkType: string
  isScreenOn: boolean
  lastOnlineTime: number
}

/**
 * 应用信息接口
 */
export interface IAppInfo {
  bundleName: string
  appName: string
}

/**
 * 应用列表结果接口
 */
export interface AppListResult {
  success: boolean
  message: string
  apps: IAppInfo[]
}

/**
 * 应用管理接口
 */
export interface IAppManager {
  /**
   * 安装应用
   * @param apkPath 应用安装包路径
   */
  install(apkPath: string): Promise<OperationResult>

  /**
   * 卸载应用
   * @param bundleName 应用包名
   */
  uninstall(bundleName: string): Promise<OperationResult>

  /**
   * 获取已安装应用列表
   */
  getAppList(): Promise<AppListResult>
}

/**
 * 限制策略接口
 */
export interface IRestrictionManager {
  /**
   * 设置WiFi禁用状态
   * @param disabled 是否禁用
   */
  setWifiDisabled(disabled: boolean): Promise<OperationResult>

  /**
   * 设置移动数据禁用状态
   * @param disabled 是否禁用
   */
  setMobileDataDisabled(disabled: boolean): Promise<OperationResult>

  /**
   * 设置蓝牙禁用状态
   * @param disabled 是否禁用
   */
  setBluetoothDisabled(disabled: boolean): Promise<OperationResult>

  /**
   * 设置GPS开关
   * @param enabled 是否启用
   */
  setGpsEnabled(enabled: boolean): Promise<OperationResult>

  /**
   * 设置相机禁用状态
   * @param disabled 是否禁用
   */
  setCameraDisabled(disabled: boolean): Promise<OperationResult>

  /**
   * 设置麦克风禁用状态
   * @param disabled 是否禁用
   */
  setMicrophoneDisabled(disabled: boolean): Promise<OperationResult>

  /**
   * 设置USB调试禁用状态
   * @param disabled 是否禁用
   */
  setUsbDebugDisabled(disabled: boolean): Promise<OperationResult>

  /**
   * 设置截图禁用状态
   * @param disabled 是否禁用
   */
  setScreenshotDisabled(disabled: boolean): Promise<OperationResult>
}

/**
 * 设备信息结果接口
 */
export interface DeviceInfoResult {
  success: boolean
  message: string
  data: IDeviceInfo | null
}

/**
 * 信息查询接口
 */
export interface IInfoQuerier {
  /**
   * 获取设备信息
   */
  getDeviceInfo(): Promise<DeviceInfoResult>

  /**
   * 获取已安装应用列表
   */
  getAppList(): Promise<AppListResult>
}
