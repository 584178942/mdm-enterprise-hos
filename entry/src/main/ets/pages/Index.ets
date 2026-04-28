import { MdmApiFactory } from '../mdm/MdmApiFactory'
import { getMqttBackgroundService } from '../service/MqttBackgroundService'
import { MqttConnectionState } from '../mqtt/MqttClient'
import { HeartbeatAdjuster } from '../battery/HeartbeatAdjuster'
import { NetworkType } from '../network/NetworkMonitor'
import { ConfigStore } from '../storage/ConfigStore'
import { hilog } from '@kit.PerformanceAnalysisKit'
import router from '@ohos.router'

const TAG = 'Index'
const DOMAIN = 0x0001

/**
 * 设备状态数据
 */
interface DeviceStatus {
  deviceId: string
  connectionState: string
  batteryLevel: number
  isCharging: boolean
  networkType: string
  heartbeatMode: string
  lastHeartbeat: string
}

/**
 * 命令执行历史
 */
interface CommandHistory {
  id: number
  action: string
  status: string
  time: string
}

@Entry
@Component
struct Index {
  @State deviceStatus: DeviceStatus = {
    deviceId: '加载中...',
    connectionState: '未连接',
    batteryLevel: 0,
    isCharging: false,
    networkType: '未知',
    heartbeatMode: '正常',
    lastHeartbeat: '-'
  }

  @State commandHistory: CommandHistory[] = []
  @State testCommandLog: string = ''

  private heartbeatAdjuster: HeartbeatAdjuster | null = null
  private timerHandle: number = 0

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Index page about to appear')
    this.initData()
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, 'Index page about to disappear')
    if (this.timerHandle !== 0) {
      clearInterval(this.timerHandle)
    }
  }

  async initData() {
    // 获取设备ID
    try {
      const deviceId = await ConfigStore.getDeviceId()
      this.deviceStatus.deviceId = deviceId
    } catch {
      this.deviceStatus.deviceId = '未知'
    }

    // 获取心跳调整器
    const service = getMqttBackgroundService()
    this.heartbeatAdjuster = service.getHeartbeatAdjuster()

    // 启动定时刷新
    this.timerHandle = setInterval(() => {
      this.refreshStatus()
    }, 2000)

    // 初始刷新
    this.refreshStatus()
  }

  refreshStatus() {
    const service = getMqttBackgroundService()

    // 连接状态
    const state = service.getConnectionState()
    this.deviceStatus.connectionState = this.getConnectionStateText(state)

    // 电池信息
    if (this.heartbeatAdjuster) {
      const batteryInfo = this.heartbeatAdjuster.getBatteryInfo()
      this.deviceStatus.batteryLevel = batteryInfo.batterySOC
      this.deviceStatus.isCharging = batteryInfo.isCharging

      const networkInfo = this.heartbeatAdjuster.getNetworkInfo()
      this.deviceStatus.networkType = networkInfo.networkType

      this.deviceStatus.heartbeatMode = this.heartbeatAdjuster.getModeDescription()
    }
  }

  getConnectionStateText(state: MqttConnectionState | null): string {
    if (!state) return '未初始化'
    switch (state) {
      case MqttConnectionState.CONNECTED:
        return '已连接'
      case MqttConnectionState.CONNECTING:
        return '连接中...'
      case MqttConnectionState.RECONNECTING:
        return '重连中...'
      case MqttConnectionState.DISCONNECTED:
        return '未连接'
      case MqttConnectionState.ERROR:
        return '错误'
      default:
        return '未知'
    }
  }

  getBatteryColor(level: number): ResourceColor {
    if (level < 20) return '#FF3B30' // 红色
    if (level < 50) return '#FF9500' // 橙色
    return '#34C759' // 绿色
  }

  build() {
    Scroll() {
      Column() {
        // 标题栏
        Row() {
          Text('MDM 企业移动管理')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)

          Blank()

          Text('设置')
            .fontSize(16)
            .fontColor('#007AFF')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .onClick(() => {
              router.push({ uri: 'pages/Settings' })
            })
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })

        // 设备状态卡片
        Column() {
          Text('设备状态')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding({ bottom: 15 })

          // 设备ID
          Row() {
            Text('设备ID:')
              .fontSize(14)
              .width(100)
            Text(this.deviceStatus.deviceId)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ bottom: 8 })

          // 连接状态
          Row() {
            Text('连接状态:')
              .fontSize(14)
              .width(100)
            Text(this.deviceStatus.connectionState)
              .fontSize(14)
              .fontColor(this.deviceStatus.connectionState === '已连接' ? '#34C759' : '#FF9500')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding({ bottom: 8 })

          // 电池状态
          Row() {
            Text('电池:')
              .fontSize(14)
              .width(100)
            Progress({ value: this.deviceStatus.batteryLevel, total: 100, type: ProgressType.Capsule })
              .color(this.getBatteryColor(this.deviceStatus.batteryLevel))
              .width(120)
              .height(16)
            Text(`${this.deviceStatus.batteryLevel}% ${this.deviceStatus.isCharging ? '⚡' : ''}`)
              .fontSize(12)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ bottom: 8 })

          // 网络类型
          Row() {
            Text('网络:')
              .fontSize(14)
              .width(100)
            Text(this.deviceStatus.networkType)
              .fontSize(14)
          }
          .width('100%')
          .padding({ bottom: 8 })

          // 心跳模式
          Row() {
            Text('心跳模式:')
              .fontSize(14)
              .width(100)
            Text(this.deviceStatus.heartbeatMode)
              .fontSize(14)
              .fontColor('#007AFF')
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })

        // 测试命令区域
        Column() {
          Text('MQTT命令测试 (Mock模式)')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding({ bottom: 15 })

          Text('点击按钮发送测试命令到MQTT服务器')
            .fontSize(12)
            .fontColor('#8E8E93')
            .width('100%')
            .padding({ bottom: 15 })

          // 命令按钮网格
          Grid() {
            GridItem() {
              this.TestButton('锁定设备', 'lock')
            }
            GridItem() {
              this.TestButton('解锁设备', 'unlock')
            }
            GridItem() {
              this.TestButton('重启设备', 'reboot')
            }
            GridItem() {
              this.TestButton('获取设备信息', 'get_device_info')
            }
            GridItem() {
              this.TestButton('禁用WiFi', 'disable_wifi')
            }
            GridItem() {
              this.TestButton('启用WiFi', 'enable_wifi')
            }
            GridItem() {
              this.TestButton('禁用相机', 'disable_camera')
            }
            GridItem() {
              this.TestButton('启用相机', 'enable_camera')
            }
          }
          .width('100%')
          .columnsTemplate('1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)

          // 日志输出
          Column() {
            Text('命令日志:')
              .fontSize(12)
              .fontColor('#8E8E93')
              .width('100%')
              .padding({ bottom: 5 })

            Scroll() {
              Text(this.testCommandLog)
                .fontSize(10)
                .fontFamily('monospace')
                .width('100%')
            }
            .width('100%')
            .height(100)
            .backgroundColor('#1C1C1E')
            .borderRadius(8)
            .padding(8)
          }
          .width('100%')
          .padding({ top: 15 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 16 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })

        // MDM能力说明
        Column() {
          Text('MDM功能说明')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding({ bottom: 15 })

          Text('当前运行在 Mock 模式下，所有MDM命令均为模拟执行。')
            .fontSize(14)
            .fontColor('#FF9500')
            .width('100%')
            .padding({ bottom: 10 })

          Text('如需使用真实MDM能力:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding({ bottom: 5 })

          Text('1. 申请企业MDM证书')
            .fontSize(14)
            .fontColor('#8E8E93')
            .width('100%')
          Text('2. 配置签名证书(.p7b)')
            .fontSize(14)
            .fontColor('#8E8E93')
            .width('100%')
          Text('3. 将MdmApiFactory.USE_MOCK改为false')
            .fontSize(14)
            .fontColor('#8E8E93')
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ top: 16 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F2F2F7')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  TestButton(label: string, action: string) {
    Button(label)
      .fontSize(12)
      .width('100%')
      .height(40)
      .backgroundColor('#007AFF')
      .borderRadius(8)
      .onClick(() => {
        this.sendTestCommand(action, label)
      })
  }

  async sendTestCommand(action: string, label: string) {
    const timestamp = new Date().toLocaleTimeString()
    const logEntry = `[${timestamp}] 发送命令: ${label} (${action})\n`

    this.testCommandLog = logEntry + this.testCommandLog

    // 获取设备ID
    const deviceId = await ConfigStore.getDeviceId()

    // 模拟命令执行
    const mockResults: Record<string, string> = {
      'lock': '设备已锁定(Mock)',
      'unlock': '设备已解锁(Mock)',
      'reboot': '设备重启(Mock)',
      'get_device_info': '设备信息查询成功(Mock)',
      'disable_wifi': 'WiFi已禁用(Mock)',
      'enable_wifi': 'WiFi已启用(Mock)',
      'disable_camera': '相机已禁用(Mock)',
      'enable_camera': '相机已启用(Mock)'
    }

    const result = mockResults[action] || '执行成功'
    const resultEntry = `[${timestamp}] 执行结果: ${result}\n`
    this.testCommandLog = resultEntry + this.testCommandLog

    hilog.info(DOMAIN, TAG, 'Test command: %{public}s, result: %{public}s', action, result)
  }
}
