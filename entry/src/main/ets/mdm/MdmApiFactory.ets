import { IDeviceController, IAppManager, IRestrictionManager, IInfoQuerier } from './IDeviceController'
import { DeviceControllerMock } from './DeviceControllerMock'
import { AppManagerMock } from './AppManagerMock'
import { RestrictionManagerMock } from './RestrictionManagerMock'
import { InfoQuerierMock } from './InfoQuerierMock'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'MdmApiFactory'
const DOMAIN = 0x0001

// TODO: 获取证书后，将此值改为 false
const USE_MOCK = true

// 模块级单例实例
let deviceControllerInstance: IDeviceController | null = null
let appManagerInstance: IAppManager | null = null
let restrictionManagerInstance: IRestrictionManager | null = null
let infoQuerierInstance: IInfoQuerier | null = null

/**
 * MDM API工厂类
 * 根据是否获得企业MDM证书，自动选择Mock或Real实现
 *
 * 使用方式:
 * const deviceCtrl = MdmApiFactory.getDeviceController()
 *
 * 切换到Real模式:
 * 将 USE_MOCK 改为 false，并确保已获取企业MDM证书
 */
export class MdmApiFactory {
  /**
   * 获取设备控制器实例
   */
  static getDeviceController(): IDeviceController {
    if (!deviceControllerInstance) {
      if (USE_MOCK) {
        hilog.info(DOMAIN, TAG, 'Using Mock DeviceController')
        deviceControllerInstance = new DeviceControllerMock()
      } else {
        // TODO: 获取证书后，取消注释以下行
        // deviceControllerInstance = new DeviceController()
        hilog.error(DOMAIN, TAG, 'Real DeviceController not implemented yet')
        deviceControllerInstance = new DeviceControllerMock()
      }
    }
    return deviceControllerInstance
  }

  /**
   * 获取应用管理器实例
   */
  static getAppManager(): IAppManager {
    if (!appManagerInstance) {
      if (USE_MOCK) {
        hilog.info(DOMAIN, TAG, 'Using Mock AppManager')
        appManagerInstance = new AppManagerMock()
      } else {
        // TODO: 获取证书后，取消注释以下行
        // appManagerInstance = new AppManager()
        hilog.error(DOMAIN, TAG, 'Real AppManager not implemented yet')
        appManagerInstance = new AppManagerMock()
      }
    }
    return appManagerInstance
  }

  /**
   * 获取限制策略管理器实例
   */
  static getRestrictionManager(): IRestrictionManager {
    if (!restrictionManagerInstance) {
      if (USE_MOCK) {
        hilog.info(DOMAIN, TAG, 'Using Mock RestrictionManager')
        restrictionManagerInstance = new RestrictionManagerMock()
      } else {
        // TODO: 获取证书后，取消注释以下行
        // restrictionManagerInstance = new RestrictionManager()
        hilog.error(DOMAIN, TAG, 'Real RestrictionManager not implemented yet')
        restrictionManagerInstance = new RestrictionManagerMock()
      }
    }
    return restrictionManagerInstance
  }

  /**
   * 获取信息查询器实例
   */
  static getInfoQuerier(): IInfoQuerier {
    if (!infoQuerierInstance) {
      if (USE_MOCK) {
        hilog.info(DOMAIN, TAG, 'Using Mock InfoQuerier')
        infoQuerierInstance = new InfoQuerierMock()
      } else {
        // TODO: 获取证书后，取消注释以下行
        // infoQuerierInstance = new InfoQuerier()
        hilog.error(DOMAIN, TAG, 'Real InfoQuerier not implemented yet')
        infoQuerierInstance = new InfoQuerierMock()
      }
    }
    return infoQuerierInstance
  }

  /**
   * 重置所有实例（用于测试或切换模式）
   */
  static reset(): void {
    deviceControllerInstance = null
    appManagerInstance = null
    restrictionManagerInstance = null
    infoQuerierInstance = null
    hilog.info(DOMAIN, TAG, 'MdmApiFactory reset')
  }
}
