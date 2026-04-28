/**
 * MDM模块导出
 * 统一导出MDM相关的接口和类
 */
export {
  IDeviceController,
  IDeviceInfo,
  IAppInfo,
  IAppManager,
  IRestrictionManager,
  IInfoQuerier,
  OperationResult,
  AppListResult,
  DeviceInfoResult
} from './IDeviceController'

export { DeviceControllerMock } from './DeviceControllerMock'
export { AppManagerMock } from './AppManagerMock'
export { RestrictionManagerMock } from './RestrictionManagerMock'
export { InfoQuerierMock } from './InfoQuerierMock'
export { MdmApiFactory } from './MdmApiFactory'
