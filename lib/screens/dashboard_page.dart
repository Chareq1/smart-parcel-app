import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:smart_parcel_box_app/services/mqtt_service.dart';
import 'package:smart_parcel_box_app/services/camera_service.dart';
import 'package:smart_parcel_box_app/models/parcel_box_data.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late CameraService camera;
  late ParcelBoxData parcelBoxData = ParcelBoxData(temperatureCelsius: 25.0, temperatureFahrenheit:  75.0, doorState: false, parcelCount: 0, distance: 0.0, electromagneticLock: true, humidity: 50.0);
  late MQTTService mqtt = MQTTService('192.168.1.247', ['smart-parcel-box/data'], onMessage: (topic, payload) {
    if (topic == 'smart-parcel-box/data') {
      setState(() {
        parcelBoxData = ParcelBoxData.fromJson(
          Map<String, dynamic>.from(jsonDecode(payload)),
        );
      });
    }
  });

  @override
  void initState() {
    super.initState();
    mqtt.connect();
    camera = CameraService('rtsp://192.168.1.247:8554/cam');
  }

  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
          children:[
            Expanded(
              child: Video(
                controller: camera.controller,
                controls: NoVideoControls,
              ),
            ),
            Text('Stan drzwi: ${parcelBoxData.doorState ? "Otwarte" : "Zamknięte"}'),
            Text('Liczba paczek: ${parcelBoxData.parcelCount}'),
            Text('Dystans: ${parcelBoxData.distance.toStringAsFixed(2)} cm'),
            Text('Elektromagnetyczny zamek: ${parcelBoxData.electromagneticLock ? "Zamknięty" : "Otwarty"}'),
            Text('Temperatura (°C): ${parcelBoxData.temperatureCelsius.toStringAsFixed(1)}'),
            Text('Temperatura (°F): ${parcelBoxData.temperatureFahrenheit.toStringAsFixed(1)}'),
            Text('Wilgotność: ${parcelBoxData.humidity.toStringAsFixed(1)}%'),
        ]
      ),
    );
  }
}
