import { batteryInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'BatteryMonitor';
const DOMAIN = 0x0001;

export interface BatteryInfo {
  batterySOC: number;        // 电量百分比
  isCharging: boolean;       // 是否充电中（由 chargingStatus 计算）
  isScreenOn: boolean;       // 屏幕是否亮起
  chargingStatus: number;    // 原始充电状态（0-未充电，1-充电中，2-已充满）
}

export type BatteryChangeListener = (info: BatteryInfo) => void;

export class BatteryMonitor {
  private listeners: BatteryChangeListener[] = [];
  private lastInfo: BatteryInfo | null = null;  // 保留，getLastInfo 中会使用
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;

  constructor() {
    this.initBatteryEvent();
  }

  /**
   * 根据充电状态码判断是否在充电中
   * API 21 中 batteryInfo.chargingStatus 取值：
   * 0 - 未充电，1 - 充电中，2 - 已充满（通常视为充电中）
   */
  private static isChargingByStatus(status: number): boolean {
    return status === 1 || status === 2;
  }

  getInfo(): BatteryInfo {
    try {
      const chargingStatus = batteryInfo.chargingStatus;
      const info: BatteryInfo = {
        batterySOC: batteryInfo.batterySOC,
        isCharging: BatteryMonitor.isChargingByStatus(chargingStatus),
        isScreenOn: this.isScreenOn(),
        chargingStatus: chargingStatus
      };
      this.lastInfo = info;
      return info;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to get battery info: %{public}d, %{public}s', error.code, error.message);
      return {
        batterySOC: 100,
        isCharging: false,
        isScreenOn: true,
        chargingStatus: 0
      };
    }
  }

  private isScreenOn(): boolean {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      // API 21 中 DisplayState.STATE_ON = 2
      return displayInfo.state === 2;
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Get screen state failed: %{public}s', error.message);
      return true;
    }
  }

  private async initBatteryEvent(): Promise<void> {
    // 使用字符串常量，兼容 API 21（commonEventManager.Support 可能不存在）
    const event = 'usual.event.BATTERY_CHANGED';
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [event]
    };

    try {
      this.subscriber = await commonEventManager.createSubscriber(subscribeInfo);
      // 订阅时回调，data 参数虽然没有显式使用，但保留参数名（或改为 _data 消除警告）
      commonEventManager.subscribe(this.subscriber, (_err: BusinessError | null, _data?: commonEventManager.CommonEventData) => {
        // 电池变化时通知所有监听器
        this.notifyListeners();
      });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Create subscriber failed: %{public}s', error.message);
    }
  }

  onChange(listener: BatteryChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
    // 立即触发一次当前状态
    listener(this.getInfo());
  }

  off(listener: BatteryChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index !== -1) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners(): void {
    const info = this.getInfo();
    for (const listener of this.listeners) {
      try {
        listener(info);
      } catch (err) {
        const error = err as BusinessError;
        hilog.error(DOMAIN, TAG, 'Battery listener error: %{public}s', error.message);
      }
    }
  }

  isLowBattery(): boolean {
    const info = this.getInfo();
    return info.batterySOC < 20 && !info.isCharging;
  }

  isPowerSaving(): boolean {
    const info = this.getInfo();
    return info.batterySOC < 20 || (!info.isCharging && info.batterySOC < 50);
  }

  getLastInfo(): BatteryInfo | null {
    return this.lastInfo;
  }

  release(): void {
    if (this.subscriber) {
      try {
        commonEventManager.unsubscribe(this.subscriber);
      } catch (err) {
        const error = err as BusinessError;
        hilog.error(DOMAIN, TAG, 'Unsubscribe failed: %{public}s', error.message);
      }
      this.subscriber = null;
    }
    this.listeners = [];
  }
}