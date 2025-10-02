import 'dart:io';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late final MqttServerClient mqttClient;
  final Uuid uuid = const Uuid();
  late final String username;
  final Function(String topic, String payload)? onMessage;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  bool isBrokerConnected = false;

  MQTTService(
      String broker,
      List<String> topics, {
        this.onMessage,
        this.onConnected,
        this.onDisconnected,
      }) {
    username = 'flutter_client_${uuid.v4()}';
    mqttClient = MqttServerClient(broker, username);
    mqttClient.secure = true;
    mqttClient.securityContext = SecurityContext.defaultContext;
    mqttClient.securityContext = SecurityContext.defaultContext;
    mqttClient.port = 8883;
    mqttClient.logging(on: true);
    mqttClient.keepAlivePeriod = 20;

    mqttClient.onConnected = () {
      isBrokerConnected = true;
      onConnected?.call();
      for (final topic in topics) {
        mqttClient.subscribe(topic, MqttQos.atMostOnce);
      }
    };

    mqttClient.onDisconnected = () {
      isBrokerConnected = false;
      onDisconnected?.call();
    };
  }

  Future<void> connect() async {
    try {
      await mqttClient.connect();
      mqttClient.updates!.listen((messages) {
        for (final message in messages) {
          final MqttReceivedMessage<MqttMessage> receivedMessage = message;
          final MqttPublishMessage publishMessage =
          receivedMessage.payload as MqttPublishMessage;
          final String topic = receivedMessage.topic;
          final String payload = MqttPublishPayload.bytesToStringAsString(
              publishMessage.payload.message);
          if (onMessage != null) onMessage!(topic, payload);
        }
      });
    } catch (e) {
      isBrokerConnected = false;
      mqttClient.disconnect();
      onDisconnected?.call();
    }
  }

  void reset() {
    if (isBrokerConnected) {
      mqttClient.disconnect();
    }
    final String newUsername = 'flutter_client_${uuid.v4()}';
    mqttClient.clientIdentifier = newUsername;
    connect();
  }

  void publish(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    mqttClient.publishMessage(
        topic, MqttQos.atMostOnce, builder.payload!);
  }

  void disconnect() {
    if (isBrokerConnected) {
      mqttClient.disconnect();
    }
  }

  void dispose() {
    mqttClient.disconnect();
  }
}