import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parcel_box_app/services/mqtt_service.dart';
import 'package:smart_parcel_box_app/services/camera_service.dart';
import 'package:smart_parcel_box_app/models/parcel_box_data.dart';
import 'package:smart_parcel_box_app/theme/theme.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../theme/theme_provider.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}


class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  bool _isOnline = false;
  Timer? _statusTimer;
  Timer? _checkStatusTimer;
  Timer? _internetCheckTimer;
  bool _isDeviceConnectedToInternet = true;

  late String name = '';
  late String description = '';

  late int minimalTemperature = 0;
  late int maximalTemperature = 0;
  late int minimalHumidity = 0;
  late int maximalHumidity = 0;
  late int ultrasonicThreshold = 0;

  late CameraService camera;
  late ParcelBoxData parcelBoxData = ParcelBoxData(temperature: 25.0, doorState: false, parcelCount: 0, isSpaceAvailable: true, mainDoorElectromagneticLock: true, parcelDoorStepMotorLock: true, humidity: 50);

  // MQTT Service
  late MQTTService mqtt = MQTTService('mqtt.smaartparcelbox.app',
    ['smart-parcel-box/data', 'smart-parcel-box/status', 'smart-parcel-box/settings'],
    onMessage: (topic, payload) {
      if (topic == 'smart-parcel-box/status') {
        var response = jsonDecode(payload);
        _statusTimer?.cancel();

        _statusTimer = Timer(const Duration(seconds: 10), () {
          camera.dispose();
          setState(() => _isOnline = false);
        });

        if (response['online'] == true) {
          if(!_isOnline) {
            camera = CameraService('rtsp://rtsp.smaartparcelbox.app:8554/cam');
            camera.connect();
          }
          setState(() => _isOnline = true);
        } else {
          camera.dispose();
          setState(() => _isOnline = false);
        }

        setState(() => name = response['name'] ?? 'Parcel Box');
        setState(() => description = response['description'] ?? 'My parcel box');

        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('name', name);
          prefs.setString('description', description);
        });

        const pubTopic = 'smart-parcel-box/cmd/get-settings';
        final builder = MqttClientPayloadBuilder();
        mqtt.mqttClient.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);
      }
      else if (topic == 'smart-parcel-box/settings') {
        var response = jsonDecode(payload);
        setState(() {
          minimalTemperature = response['minimal_temperature'] ?? 0.0;
          maximalTemperature = response['maximal_temperature'] ?? 50.0;
          minimalHumidity = response['minimal_humidity'] ?? 0;
          maximalHumidity = response['maximal_humidity'] ?? 75;
        });
      }
      else if (topic == 'smart-parcel-box/data') {
        setState(() {
          parcelBoxData = ParcelBoxData.fromJson(
            Map<String, dynamic>.from(jsonDecode(payload)),
          );
        });
      }
    },
  );


  // METHODS
  Future<void> checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isDeviceConnectedToInternet = (connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi)) ? true : false;
    });
  }

  void checkIfParcelBoxIsOnline() {
    if (mqtt.isBrokerConnected) {
        const pubTopic = 'smart-parcel-box/cmd/check-status';
        final builder = MqttClientPayloadBuilder();
        mqtt.mqttClient.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  Future<bool?> showUnloadDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              'Unload box',
              style: TextStyle(
                color: Theme
                    .of(context)
                    .textTheme
                    .titleLarge
                    ?.color,
              ),
            ),
            content: Text(
              'Have you taken all boxes from parcel box?',
              style: TextStyle(
                color: Theme
                    .of(context)
                    .textTheme
                    .bodyLarge
                    ?.color,
              ),
            ),
            actions: [
              TextButton(
                child: Text('No', style: TextStyle(color: Theme
                    .of(context)
                    .colorScheme
                    .primary)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text('Tak', style: TextStyle(color: Theme
                    .of(context)
                    .colorScheme
                    .primary)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
    );
  }

  void _showParcelCountDialog() {
    int newParcelCount = 1;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add parcels"),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: "How many new parcels?"),
            onChanged: (value) {
              newParcelCount = int.tryParse(value) ?? 1;
            },
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text("Add"),
              onPressed: () {
                Navigator.of(context).pop();
                _sendParcelCount(newParcelCount);
              },
            ),
          ],
        );
      },
    );
  }

  void _sendParcelCount(int count) {
    const pubTopic = 'smart-parcel-box/cmd/add-parcels';
    final builder = MqttClientPayloadBuilder();
    builder.addString(count.toString());
    mqtt.mqttClient.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  void initState() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.initState();

    _internetCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkInternetConnection();
    });

    checkInternetConnection();

    WidgetsBinding.instance.addObserver(this);
    mqtt.connect().then((_) {
      checkIfParcelBoxIsOnline();
    });
    _requestNotificationPermission();
    _initFirebaseMessaging();

    SharedPreferences.getInstance().then((prefs) {
      name = prefs.getString('name') ?? 'Smart Parcel Box';
      description = prefs.getString('description') ?? 'My parcel box';
    });
  }


  void _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('User granted permission');
    } else {
      developer.log('User declined or has not accepted permission');
    }
  }

  void _initFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Received foreground message: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('Notification opened: ${message.notification?.title}');
    });

    FirebaseMessaging.instance.subscribeToTopic('all_users');
  }


  @override
  void dispose() {
    _statusTimer?.cancel();
    _checkStatusTimer?.cancel();
    _internetCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      mqtt.reset();
      checkInternetConnection();
      checkIfParcelBoxIsOnline();
      if (_isOnline) {
        camera.connect();
      }
    }
  }


  // WIDGETS
  Widget buildButton(IconData? icon, String? iconText, String value, VoidCallback? onPressedFunction, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onPressedFunction,
      child: Card(
        color: Colors.green,
        margin: const EdgeInsets.all(5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 5, top: 5, bottom: 5, right: 10),
              child: Card(
                color: Colors.green[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: icon != null
                      ? Icon(icon, size: 25, color: color)
                      : Container(
                          width: 25,
                          height: 25,
                          alignment: Alignment.center,
                          child: Text(
                            iconText ?? "",
                            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTile(IconData icon, String label, String value, {Color color = Colors.white}) {
    return Card(
      color: Colors.lightBlue,
      margin: const EdgeInsets.all(5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 5, top: 5, bottom: 5, right: 10),
            child: Card (
              color: Colors.blue[500],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(icon, size: 25, color: color),
              )
            ),
          ),
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ]
          ),
        ],
      ),
    );
  }


  // MAIN BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme
          .of(context)
          .scaffoldBackgroundColor,
      appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                  children: [
                    Icon(LucideIcons.package500, size: 40),
                    const SizedBox(width: 10),
                    Text("Smart Parcel Box", style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 20)),
                  ]
              ),
              Row(
                  children: [
                    Ink(
                      child: IconButton(
                          icon: Provider
                              .of<ThemeProvider>(context)
                              .currentThemeData == lightMode ? Icon(
                              LucideIcons.moon500, size: 25) : Icon(
                              LucideIcons.sun500, size: 25),
                          onPressed: () {
                            Provider
                                .of<ThemeProvider>(context, listen: false)
                                .toggleTheme();
                          }
                      ),
                    ),
                    Ink(
                      decoration: const ShapeDecoration(
                          color: Colors.lightBlue, shape: CircleBorder()),
                      child: IconButton(
                          icon: Icon(
                              LucideIcons.settings500, color: Colors.white,
                              size: 25),
                          onPressed: () {}
                      ),
                    )
                  ]
              )
            ],
          ),
          backgroundColor: Theme
              .of(context)
              .scaffoldBackgroundColor,
          elevation: 0
      ),
      body: !_isDeviceConnectedToInternet ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.wifiOff, color: Colors.red, size: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child:  Text(
                "No connection",
                style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.red),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                  "Your device is not connected to the internet.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey)
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => checkInternetConnection(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.refreshCcw500, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Reconnect", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ) : Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const SizedBox(height: 13),

            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 15, left: 0),
                        child: SizedBox(
                          width: 175,
                          height: 500,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                            ),
                            child: Image.asset(
                              'assets/images/parcel_box.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topLeft,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 5, top: 15, right: 15, bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900)),
                                    Text(description,
                                        style: TextStyle(
                                            color: Colors.white70)),
                                  ]
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _isOnline ? Colors.green : Colors
                                          .red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment
                                            .end,
                                        children: [
                                          Icon(
                                            _isOnline
                                                ? LucideIcons.wifi500
                                                : LucideIcons.wifiOff500,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _isOnline ? "Online" : "Offline",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700),
                                          )
                                        ]
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (!_isOnline)
              Expanded(
                flex: 4,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.wifiOff, color: Colors.red, size: 50),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Text(
                            "Offline",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Theme
                                    .of(context)
                                    .colorScheme
                                    .onBackground)
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Text(
                            "Please check the state of Parcel Box and then try to reconnect.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey)
                        ),
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton(
                        onPressed: () => checkIfParcelBoxIsOnline(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            alignment: Alignment.center
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(LucideIcons.refreshCcw500,
                                color: Colors.white),
                            SizedBox(width: 10),
                            Text("Reconnect", style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ... [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            Expanded(
                                flex: 1,
                                child: buildButton(
                                  parcelBoxData.mainDoorElectromagneticLock
                                      ? LucideIcons.lockKeyhole500
                                      : LucideIcons.lockKeyholeOpen500,
                                  null,
                                  parcelBoxData.mainDoorElectromagneticLock
                                      ? "Unlock door"
                                      : "Lock door",
                                      () {
                                    if (_isOnline) {
                                      setState(() {
                                        if (parcelBoxData
                                            .mainDoorElectromagneticLock) {
                                          const pubTopic = 'smart-parcel-box/cmd/unlock-main-door';
                                          final builder = MqttClientPayloadBuilder();
                                          parcelBoxData
                                              .mainDoorElectromagneticLock =
                                          false;
                                          mqtt.mqttClient.publishMessage(
                                              pubTopic, MqttQos.atLeastOnce,
                                              builder.payload!);
                                        } else {
                                          const pubTopic = 'smart-parcel-box/cmd/lock-main-door';
                                          final builder = MqttClientPayloadBuilder();
                                          parcelBoxData
                                              .mainDoorElectromagneticLock =
                                          true;
                                          mqtt.mqttClient.publishMessage(
                                              pubTopic, MqttQos.atLeastOnce,
                                              builder.payload!);
                                        }
                                      });
                                    }
                                  },
                                  color: Colors.white,
                                )
                            ),
                            Expanded(
                                flex: 1,
                                child: buildButton(
                                  parcelBoxData.parcelDoorStepMotorLock
                                      ? LucideIcons.archiveX500
                                      : LucideIcons.archiveRestore500,
                                  null,
                                  parcelBoxData.parcelDoorStepMotorLock
                                      ? "Unlock side"
                                      : "Lock side",
                                      () {
                                    if (_isOnline) {
                                      setState(() {
                                        if (parcelBoxData.parcelDoorStepMotorLock) {
                                          const pubTopic = 'smart-parcel-box/cmd/unlock-parcel-door';
                                          final builder = MqttClientPayloadBuilder();
                                          parcelBoxData.parcelDoorStepMotorLock = false;
                                          mqtt.mqttClient.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);
                                        } else {
                                          const pubTopic = 'smart-parcel-box/cmd/lock-parcel-door';
                                          final builder = MqttClientPayloadBuilder();
                                          parcelBoxData.parcelDoorStepMotorLock = true;
                                          mqtt.mqttClient.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);
                                        }
                                      });
                                    }
                                  },
                                  color: Colors.white,
                                )
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            Expanded(
                                flex: 1,
                                child: buildButton(
                                    LucideIcons.download500,
                                    null,
                                    "Load box",
                                        () {
                                      if (_isOnline) {
                                        const unlockTopic = 'smart-parcel-box/cmd/unlock-main-door';
                                        final unlockBuilder = MqttClientPayloadBuilder();
                                        mqtt.mqttClient.publishMessage(unlockTopic, MqttQos.atLeastOnce, unlockBuilder.payload!);

                                        _showParcelCountDialog();
                                      }
                                    },
                                    color: Colors.white
                                )
                            ),
                            Expanded(
                                flex: 1,
                                child: buildButton(
                                    parcelBoxData.parcelCount > 0
                                        ? null
                                        : LucideIcons.boxes500,
                                    parcelBoxData.parcelCount > 0
                                        ? (parcelBoxData.parcelCount > 9
                                        ? "9+"
                                        : "${parcelBoxData.parcelCount}")
                                        : null,
                                    parcelBoxData.parcelCount > 0
                                        ? "Unload box"
                                        : "No parcels",
                                        () async {
                                          if (parcelBoxData.parcelCount > 0) {
                                            const unlockTopic = 'smart-parcel-box/cmd/unlock-main-door';
                                            final unlockBuilder = MqttClientPayloadBuilder();
                                            mqtt.mqttClient.publishMessage(unlockTopic, MqttQos.atLeastOnce, unlockBuilder.payload!);
                                            var result = await showUnloadDialog(context);
                                            while (result != true) {
                                              result = await showUnloadDialog(context);
                                            }
                                            if (result == true) {
                                              if (_isOnline) {
                                                const pubTopic = 'smart-parcel-box/cmd/unload-box';
                                                final builder = MqttClientPayloadBuilder();
                                                mqtt.mqttClient.publishMessage(
                                                    pubTopic, MqttQos.atLeastOnce,
                                                    builder.payload!);
                                              }
                                            }
                                          }
                                      },
                                      color: Colors.white
                                )
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: buildTile(parcelBoxData.temperature >
                                  maximalTemperature ? LucideIcons
                                  .thermometerSun500 : (parcelBoxData
                                  .temperature < minimalTemperature
                                  ? LucideIcons.thermometerSnowflake500
                                  : LucideIcons.thermometer500),
                                  "Temperature", "${parcelBoxData.temperature
                                      .toStringAsFixed(1)} °C",
                                  color: parcelBoxData.temperature >
                                      maximalTemperature
                                      ? Colors.redAccent
                                      : (parcelBoxData.temperature <
                                      minimalTemperature
                                      ? Colors.blue
                                      : Colors.white)),
                            ),
                            Expanded(
                              flex: 1,
                              child: buildTile(
                                  parcelBoxData.humidity > maximalHumidity
                                      ? LucideIcons.bubbles500
                                      : (parcelBoxData.humidity <
                                      minimalHumidity ? LucideIcons
                                      .dropletOff500 : LucideIcons
                                      .droplets500), "Humidity",
                                  "${parcelBoxData.humidity} %",
                                  color: parcelBoxData.humidity >
                                      maximalHumidity
                                      ? Colors.redAccent
                                      : (parcelBoxData.humidity <
                                      minimalHumidity ? Colors.blue : Colors
                                      .white)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: buildTile(
                                  parcelBoxData.doorState ? LucideIcons
                                      .doorOpen500 : LucideIcons
                                      .doorClosed500, "Door state",
                                  parcelBoxData.doorState
                                      ? "Open"
                                      : "Closed"),
                            ),
                            Expanded(
                              flex: 1,
                              child: buildTile(
                                  parcelBoxData.isSpaceAvailable ? LucideIcons
                                      .blocks500 : LucideIcons.vault500,
                                  "Space usage",
                                  parcelBoxData.isSpaceAvailable
                                      ? "Free"
                                      : "No space",
                                  color: parcelBoxData.isSpaceAvailable
                                      ? Colors.white
                                      : Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.lightBlue,
                        width: 5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Video(
                              controller: camera.controller,
                              controls: NoVideoControls,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: Colors.lightBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.aperture500,
                                  color: Colors.white, size: 25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
