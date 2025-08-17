import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart';
import 'package:smart_parcel_box_app/screens/dashboard_page.dart';

void main() {
  runApp(const SmartParcelBoxApp());
}

class SmartParcelBoxApp extends StatelessWidget {
  const SmartParcelBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    MediaKit.ensureInitialized();

    return MaterialApp(
      title: 'Smart Parcel Box App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const DashboardPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final Player player;
  late final NativePlayer native;
  late final VideoController controller;

  // MQTT
  final client = MqttServerClient('192.168.1.247', 'flutter_client');
  bool doorLocked = true;

  @override
  void initState() {
    super.initState();
    _initVLC();
    _connectMQTT();
  }

  void _initVLC() {
    player = Player();
    if(player.platform is NativePlayer) {
      const props = {
        'profile': 'low-latency',
        'untimed': '',
        'no-cache': '',
        'packet-buffering': '0',
        'packet-max_delay': '0',
        'opengl-glfinish': 'yes',
        'no-demuxer-thread': '',
        'vd-lavc-threads': '1'
      };
      for (final entry in props.entries) {
        (player.platform as NativePlayer).setProperty(entry.key, entry.value);
      }
    }
    player.open(Media('rtsp://192.168.1.247:8554/cam'));
    controller = VideoController(player);
  }

  Future<void> _connectMQTT() async {
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.port = 1883;
    client.onConnected = () => print('MQTT connected');
    client.onDisconnected = () => print('MQTT disconnected');

    try {
      await client.connect();
      print('Connected to MQTT broker');
    } catch (e) {
      print('MQTT connect error: $e');
      client.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Video(
              controller: controller,
              controls: NoVideoControls,
            ),
          )
        ],
      ),
    );
  }
}
