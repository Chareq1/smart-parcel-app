import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:smart_parcel_box_app/services/mqtt_service.dart';
import 'package:smart_parcel_box_app/services/camera_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late CameraService camera;
  late MQTTService mqtt = MQTTService('192.168.1.247', ['smart-parcel-box/data']);


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
      body: Center(child:
        Video(
          controller: camera.controller,
          controls: NoVideoControls,
        )
      ),
    );
  }
}
