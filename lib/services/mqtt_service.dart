import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late final MqttServerClient mqttClient;
  final Uuid uuid = const Uuid();
  late final String username;
  final Function(String topic, String payload)? onMessage;

  MQTTService(String broker, List<String> topics, {this.onMessage}) {
    username = 'flutter_client_${uuid.v4()}';
    mqttClient = MqttServerClient(broker, username);
    mqttClient.port = 1883;
    mqttClient.logging(on: true);
    mqttClient.keepAlivePeriod = 20;
    mqttClient.onConnected = () {
      for (final topic in topics) {
        mqttClient.subscribe(topic, MqttQos.atMostOnce);
      }
    };
  }

  Future<void> connect() async {
    try {
      await mqttClient.connect();
      mqttClient.updates!.listen((messages) {
        for (final message in messages) {
          final MqttReceivedMessage<MqttMessage> receivedMessage = message;
          final MqttPublishMessage publishMessage = receivedMessage.payload as MqttPublishMessage;
          final String topic = receivedMessage.topic;
          final String payload = MqttPublishPayload.bytesToStringAsString(publishMessage.payload.message);
          if (onMessage != null) onMessage!(topic, payload);
        }
      });
      print('MQTT connected to ${mqttClient.server}');
    } catch (e) {
      print('MQTT connection failed: $e');
      mqttClient.disconnect();
    }
  }

  void publish(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    mqttClient.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void dispose() {
    mqttClient.disconnect();
  }
}