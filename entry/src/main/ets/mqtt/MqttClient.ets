import { MqttAsync, MqttClient, MqttMessage, MqttResponse, MqttConnectOptions, MqttSubscribeOptions, MqttPublishOptions, MqttQos } from '@ohos/mqtt';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MqttConfig } from './MqttConfig';
import { ReconnectManager } from './ReconnectManager';

const TAG = 'MqttClientManager';
const DOMAIN = 0x0001;

export enum MqttConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  RECONNECTING = 'reconnecting',
  ERROR = 'error'
}

interface WillPayload {
  action: string;
  deviceId: string;
  timestamp: number;
}

interface CommandResultPayload {
  commandId: string;
  action: string;
  success: boolean;
  message: string;
  timestamp: number;
  data: Record<string, Object>;
}

interface HeartbeatPayload {
  deviceId: string;
  batteryLevel: number;
  isCharging: boolean;
  isScreenOn: boolean;
  networkType: string;
  timestamp: number;
}

interface AlertPayload {
  deviceId: string;
  alertType: string;
  alertMessage: string;
  timestamp: number;
  data: Record<string, Object>;
}

interface MessagePayload {
  topic: string;
  payload: string | Uint8Array;
}

export class MqttClientManager {
  private client: MqttClient | null = null;
  private deviceId: string = '';
  private connectionState: MqttConnectionState = MqttConnectionState.DISCONNECTED;
  private reconnectManager: ReconnectManager = new ReconnectManager();
  private reconnectTimer: number | null = null;
  private connectionListeners: Array<(state: MqttConnectionState) => void> = [];
  private messageListeners: Array<(topic: string, payload: string) => void> = [];

  initialize(deviceId: string): void {
    this.deviceId = deviceId;
    hilog.info(DOMAIN, TAG, 'Initializing MQTT client for device: %{public}s', deviceId);

    try {
      const clientId = MqttConfig.generateClientId(deviceId);
      this.client = MqttAsync.createMqtt({
        url: MqttConfig.SERVER_URI,
        clientId: clientId,
        persistenceType: 1
      });
      this.setupMessageListener();
      this.setupConnectionLostHandler();
      hilog.info(DOMAIN, TAG, 'MQTT client created successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to create MQTT client: %{public}s', JSON.stringify(err));
      this.connectionState = MqttConnectionState.ERROR;
      this.notifyConnectionListeners();
    }
  }

  private decodeMessagePayload(message: MqttMessage): string {
    try {
      const messageObj: MessagePayload = message as MessagePayload;
      const payload: string | Uint8Array = messageObj.payload;
      
      if (typeof payload === 'string') {
        return payload;
      } else if (payload instanceof Uint8Array) {
        return this.uint8ArrayToString(payload);
      } else {
        return JSON.stringify(payload);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to decode message payload: %{public}s', JSON.stringify(err));
      return '';
    }
  }

  private uint8ArrayToString(data: Uint8Array): string {
    let result: string = '';
    for (let i: number = 0; i < data.length; i++) {
      result += String.fromCharCode(data[i]);
    }
    return decodeURIComponent(encodeURIComponent(result));
  }

  private setupMessageListener(): void {
    if (!this.client) {
      return;
    }
    
    this.client.messageArrived((err: Error, data: MqttMessage) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Message receive error: %{public}s', JSON.stringify(err));
        return;
      }
      
      hilog.info(DOMAIN, TAG, 'MQTT message received on topic: %{public}s', data.topic);
      const messageStr: string = this.decodeMessagePayload(data);
      
      if (messageStr) {
        this.notifyMessageListeners(data.topic, messageStr);
      } else {
        hilog.warn(DOMAIN, TAG, 'Message payload is empty or failed to decode');
      }
    });
  }

  private setupConnectionLostHandler(): void {
    if (!this.client) {
      return;
    }
    
    this.client.connectLost((err: Error, _data: MqttResponse) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Connection lost error: %{public}s', JSON.stringify(err));
      } else {
        hilog.warn(DOMAIN, TAG, 'MQTT connection lost');
      }
      
      this.connectionState = MqttConnectionState.DISCONNECTED;
      this.reconnectManager.recordDisconnect();
      this.notifyConnectionListeners();
      this.scheduleReconnect();
    });
  }

  private subscribeDefaultTopics(): void {
    const commandTopic = MqttConfig.getCommandTopic(this.deviceId);
    const configTopic = MqttConfig.getConfigTopic(this.deviceId);
    this.subscribe(commandTopic, MqttConfig.SUBSCRIBE_QOS);
    this.subscribe(configTopic, MqttConfig.SUBSCRIBE_QOS);
    hilog.info(DOMAIN, TAG, 'Subscribed to default topics: %{public}s, %{public}s', commandTopic, configTopic);
  }

  connect(): void {
    if (!this.client) {
      hilog.error(DOMAIN, TAG, 'MQTT client not initialized');
      return;
    }
    
    if (this.connectionState === MqttConnectionState.CONNECTING) {
      hilog.warn(DOMAIN, TAG, 'MQTT already connecting');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Connecting to MQTT server: %{public}s', MqttConfig.SERVER_URI);
    this.connectionState = MqttConnectionState.CONNECTING;
    this.notifyConnectionListeners();

    const willPayloadObj: WillPayload = {
      action: 'offline',
      deviceId: this.deviceId,
      timestamp: Date.now()
    };
    const willPayload: string = JSON.stringify(willPayloadObj);

    const connectOptions: MqttConnectOptions = {
      userName: MqttConfig.USERNAME,
      password: MqttConfig.PASSWORD,
      connectTimeout: MqttConfig.CONNECTION_TIMEOUT,
      keepAliveInterval: MqttConfig.KEEP_ALIVE_INTERVAL,
      cleanSession: MqttConfig.CLEAN_SESSION,
      willOptions: {
        topicName: MqttConfig.WILL_TOPIC,
        message: willPayload,
        qos: MqttConfig.WILL_QOS as MqttQos,
        retained: MqttConfig.WILL_RETAINED
      }
    };

    this.client.connect(connectOptions, (err: Error, _data: MqttResponse) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'MQTT connect error: %{public}s', JSON.stringify(err));
        this.connectionState = MqttConnectionState.ERROR;
        this.scheduleReconnect();
        this.notifyConnectionListeners();
      } else {
        hilog.info(DOMAIN, TAG, 'MQTT connected successfully');
        this.connectionState = MqttConnectionState.CONNECTED;
        this.reconnectManager.reset();
        this.notifyConnectionListeners();
        this.subscribeDefaultTopics();
      }
    });
  }

  disconnect(): void {
    hilog.info(DOMAIN, TAG, 'Disconnecting MQTT');
    this.cancelReconnect();
    this.reconnectManager.reset();

    if (this.client) {
      try {
        this.client.disconnect((err: Error) => {
          if (err) {
            hilog.error(DOMAIN, TAG, 'MQTT disconnect error: %{public}s', JSON.stringify(err));
          }
        });
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'MQTT disconnect error: %{public}s', JSON.stringify(err));
      }
    }

    this.connectionState = MqttConnectionState.DISCONNECTED;
    this.notifyConnectionListeners();
  }

  subscribe(topic: string, qos: number = MqttConfig.SUBSCRIBE_QOS): void {
    if (!this.client || !this.isConnected()) {
      hilog.error(DOMAIN, TAG, 'Cannot subscribe: client not connected');
      return;
    }
    
    try {
      const subscribeOptions: MqttSubscribeOptions = {
        topic: topic,
        qos: qos as MqttQos
      };
      
      this.client.subscribe(subscribeOptions, (err: Error) => {
        if (err) {
          hilog.error(DOMAIN, TAG, 'Subscribe error: %{public}s', JSON.stringify(err));
        } else {
          hilog.info(DOMAIN, TAG, 'Subscribed to topic: %{public}s (QoS: %{public}d)', topic, qos);
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Subscribe error: %{public}s', JSON.stringify(err));
    }
  }

  unsubscribe(topic: string): void {
    if (!this.client) {
      return;
    }
    
    try {
      const unsubscribeOptions: MqttSubscribeOptions = {
        topic: topic,
        qos: 0 as MqttQos
      };
      
      this.client.unsubscribe(unsubscribeOptions, (err: Error) => {
        if (err) {
          hilog.error(DOMAIN, TAG, 'Unsubscribe error: %{public}s', JSON.stringify(err));
        } else {
          hilog.info(DOMAIN, TAG, 'Unsubscribed from topic: %{public}s', topic);
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Unsubscribe error: %{public}s', JSON.stringify(err));
    }
  }

  publish(topic: string, message: string, qos: number = MqttConfig.PUBLISH_QOS): Promise<boolean> {
    if (!this.client || !this.isConnected()) {
      hilog.error(DOMAIN, TAG, 'Cannot publish: client not connected');
      return Promise.resolve(false);
    }
    
    try {
      const publishOptions: MqttPublishOptions = {
        topic: topic,
        payload: message,
        qos: qos as MqttQos
      };
      
      this.client.publish(publishOptions, (err: Error) => {
        if (err) {
          hilog.error(DOMAIN, TAG, 'Publish error: %{public}s', JSON.stringify(err));
        } else {
          hilog.info(DOMAIN, TAG, 'Published to topic: %{public}s', topic);
        }
      });
      
      return Promise.resolve(true);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Publish error: %{public}s', JSON.stringify(err));
      return Promise.resolve(false);
    }
  }

  publishCommandResult(
    commandId: string,
    action: string,
    success: boolean,
    message: string,
    data: Record<string, Object> | null = null
  ): Promise<boolean> {
    const resultTopic = MqttConfig.getResultTopic(this.deviceId);
    const payloadObj: CommandResultPayload = {
      commandId: commandId,
      action: action,
      success: success,
      message: message,
      timestamp: Date.now(),
      data: data || {}
    };
    const payload: string = JSON.stringify(payloadObj);
    return this.publish(resultTopic, payload, MqttConfig.PUBLISH_QOS);
  }

  publishHeartbeat(
    batteryLevel: number,
    isCharging: boolean,
    isScreenOn: boolean,
    networkType: string
  ): Promise<boolean> {
    const heartbeatTopic = MqttConfig.getHeartbeatTopic(this.deviceId);
    const payloadObj: HeartbeatPayload = {
      deviceId: this.deviceId,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      isScreenOn: isScreenOn,
      networkType: networkType,
      timestamp: Date.now()
    };
    const payload: string = JSON.stringify(payloadObj);
    return this.publish(heartbeatTopic, payload, 0);
  }

  publishAlert(
    alertType: string,
    alertMessage: string,
    data: Record<string, Object> | null = null
  ): Promise<boolean> {
    const alertTopic = MqttConfig.getAlertTopic(this.deviceId);
    const payloadObj: AlertPayload = {
      deviceId: this.deviceId,
      alertType: alertType,
      alertMessage: alertMessage,
      timestamp: Date.now(),
      data: data || {}
    };
    const payload: string = JSON.stringify(payloadObj);
    return this.publish(alertTopic, payload, MqttConfig.PUBLISH_QOS);
  }

  isConnected(): boolean {
    return this.connectionState === MqttConnectionState.CONNECTED;
  }

  getConnectionState(): MqttConnectionState {
    return this.connectionState;
  }

  getDeviceId(): string {
    return this.deviceId;
  }

  addConnectionListener(listener: (state: MqttConnectionState) => void): void {
    this.connectionListeners.push(listener);
  }

  addMessageListener(listener: (topic: string, payload: string) => void): void {
    this.messageListeners.push(listener);
  }

  removeConnectionListener(listener: (state: MqttConnectionState) => void): void {
    const index = this.connectionListeners.indexOf(listener);
    if (index > -1) {
      this.connectionListeners.splice(index, 1);
    }
  }

  removeMessageListener(listener: (topic: string, payload: string) => void): void {
    const index = this.messageListeners.indexOf(listener);
    if (index > -1) {
      this.messageListeners.splice(index, 1);
    }
  }

  private notifyConnectionListeners(): void {
    this.connectionListeners.forEach((listener: (state: MqttConnectionState) => void) => {
      try {
        listener(this.connectionState);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Connection listener error: %{public}s', JSON.stringify(err));
      }
    });
  }

  private notifyMessageListeners(topic: string, payload: string): void {
    this.messageListeners.forEach((listener: (topic: string, payload: string) => void) => {
      try {
        listener(topic, payload);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Message listener error: %{public}s', JSON.stringify(err));
      }
    });
  }

  private scheduleReconnect(): void {
    this.cancelReconnect();
    
    if (!this.reconnectManager.shouldReconnect(0)) {
      hilog.warn(DOMAIN, TAG, 'Max reconnect count reached, stop reconnecting');
      return;
    }
    
    const delay = this.reconnectManager.getDelayMs();
    hilog.info(DOMAIN, TAG, 'Scheduling reconnect in %{public}d ms', delay);
    
    this.connectionState = MqttConnectionState.RECONNECTING;
    this.notifyConnectionListeners();
    
    this.reconnectTimer = setTimeout(() => {
      hilog.info(DOMAIN, TAG, 'Attempting reconnect...');
      this.connect();
    }, delay);
  }

  private cancelReconnect(): void {
    if (this.reconnectTimer !== null) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  release(): void {
    hilog.info(DOMAIN, TAG, 'Releasing MQTT client');
    this.cancelReconnect();
    this.connectionListeners = [];
    this.messageListeners = [];

    if (this.client) {
      try {
        this.client.disconnect((err: Error) => {
          if (err) {
            hilog.error(DOMAIN, TAG, 'Release disconnect error: %{public}s', JSON.stringify(err));
          }
        });
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Release error: %{public}s', JSON.stringify(err));
      }
      this.client = null;
    }

    this.connectionState = MqttConnectionState.DISCONNECTED;
  }
}
