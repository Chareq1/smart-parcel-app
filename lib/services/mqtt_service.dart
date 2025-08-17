import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late final MqttServerClient mqttClient;
  final Uuid uuid = const Uuid();
  late final String username;
  MQTTService(String broker, List<String> topics) {
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
          print('Received message on topic $topic: $payload');
        }
      });
      print('MQTT connected to ${mqttClient.server}');
      /*
      Fluttertoast.showToast(
          msg: "Connected to MQTT ",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
       */
    } catch (e) {
      print('MQTT connection failed: $e');
      mqttClient.disconnect();
    }
  }

  void dispose() {
    mqttClient.disconnect();
  }
}