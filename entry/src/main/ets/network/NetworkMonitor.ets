import connection from '@ohos.net.connection';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'NetworkMonitor';
const DOMAIN = 0x0001;

export enum NetworkType {
  WIFI = 'WiFi',
  CELLULAR = 'Cellular',
  ETHERNET = 'Ethernet',
  NONE = 'None',
  UNKNOWN = 'Unknown'
}

export interface NetworkInfo {
  isAvailable: boolean;
  networkType: NetworkType;
  isMetered: boolean;
}

export type NetworkChangeListener = (info: NetworkInfo) => void;

export class NetworkMonitor {
  private listeners: NetworkChangeListener[] = [];
  private lastInfo: NetworkInfo | null = null;
  private netConnection: connection.NetConnection | null = null;

  getInfo(): NetworkInfo {
    try {
      const netHandle = connection.getDefaultNetSync();
      const isAvailable = netHandle !== null;

      if (!isAvailable) {
        const noNetworkInfo: NetworkInfo = {
          isAvailable: false,
          networkType: NetworkType.NONE,
          isMetered: false
        };
        return noNetworkInfo;
      }

      const netCap = connection.getNetCapabilitiesSync(netHandle);
      let networkType: NetworkType = NetworkType.UNKNOWN;
      const bearerTypes = netCap.bearerTypes;

      if (bearerTypes.includes(connection.NetBearType.BEARER_ETHERNET)) {
        networkType = NetworkType.ETHERNET;
      } else if (bearerTypes.includes(connection.NetBearType.BEARER_WIFI)) {
        networkType = NetworkType.WIFI;
      } else if (bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR)) {
        networkType = NetworkType.CELLULAR;
      }

      // 判断是否按流量计费：如果是蜂窝网络则视为计费，否则非计费
      const isMetered = (networkType === NetworkType.CELLULAR);

      const info: NetworkInfo = {
        isAvailable: true,
        networkType: networkType,
        isMetered: isMetered
      };

      this.lastInfo = info;
      return info;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get network info: %{public}s', String(err));
      const errorInfo: NetworkInfo = {
        isAvailable: false,
        networkType: NetworkType.NONE,
        isMetered: false
      };
      return errorInfo;
    }
  }

  isNetworkAvailable(): boolean {
    return this.getInfo().isAvailable;
  }

  onChange(listener: NetworkChangeListener): void {
    this.listeners.push(listener);
    const info = this.getInfo();
    listener(info);

    // 如果已经有 netConnection 则不再重复注册
    if (this.netConnection !== null) {
      return;
    }

    try {
      this.netConnection = connection.createNetConnection();
      // 注册网络可用监听（需要传入回调）
      this.netConnection.on('netAvailable', () => {
        hilog.info(DOMAIN, TAG, 'Network available');
        this.notifyListeners();
      });
      this.netConnection.on('netUnavailable', () => {
        hilog.info(DOMAIN, TAG, 'Network unavailable');
        this.notifyListeners();
      });
      // register 方法需要传入一个回调（可选，但为了满足参数要求传空函数）
      this.netConnection.register(() => {});
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to register network listener: %{public}s', String(err));
    }
  }

  off(): void {
    try {
      if (this.netConnection) {
        // 注意：NetConnection 没有 off 方法，只需 unregister 即可
        this.netConnection.unregister(() => {});
        this.netConnection = null;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to unregister network listener: %{public}s', String(err));
    }
    this.listeners = [];
  }

  private notifyListeners(): void {
    const info = this.getInfo();
    this.listeners.forEach((listener: NetworkChangeListener) => {
      try {
        listener(info);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Network listener error: %{public}s', String(err));
      }
    });
  }

  getLastInfo(): NetworkInfo | null {
    return this.lastInfo;
  }
}
