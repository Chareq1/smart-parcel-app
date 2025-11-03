import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:smart_parcel_box_app/theme/theme.dart';
import '../theme/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? settingsChar;

  final String deviceName = "raspberrypi";
  final Guid parcelBoxServiceUuid = Guid(
    "de305d54-75b4-431b-adb2-eb6b9e546014",
  );
  final Guid parcelBoxServiceSettingsCharUuid = Guid(
    "de305d54-75b4-431b-adb2-eb6b9e546015",
  );

  bool isConnecting = false;
  bool isConnected = false;
  bool isBluetoothOn = false;
  bool deviceNotFound = false;
  String status = "Searching for devices...";

  Map<String, dynamic> settings = {};
  final _formKey = GlobalKey<FormState>();

  final Map<String, String> friendlyLabels = {
    "name": "Parcel Box Name",
    "description": "Parcel Box Description",
    "minimal_temperature": "Minimal Temperature (°C)",
    "maximal_temperature": "Maximal Temperature (°C)",
    "minimal_humidity": "Minimal Humidity (%)",
    "maximal_humidity": "Maximal Humidity (%)",
    "ultrasonic_threshold": "Minimal Package Space Distance (cm)",
    "autolock_slide_parcel_door_seconds": "Auto-Lock Slide Door Delay (s)",
    "autolock_main_door_seconds": "Auto-Lock Main Door Delay (s)",
    "open_main_door_duration_seconds": "Maximum Time For Opened Main Door(s)",
    "data_publish_interval": "Parcel Box Data Publish Interval (s)",
    "status_publish_interval": "Parcel Box Status Publish Interval (s)",
    "courier_button_wait_time_seconds": "Maximum Courier Wait Time (s)",
  };

  @override
  void initState() {
    super.initState();
    checkBluetoothStatus();
  }

  Future<void> checkBluetoothStatus() async {
    await _requestPermissions();

    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.on) {
        setState(() => isBluetoothOn = true);
        startScan();
      } else {
        setState(() {
          isBluetoothOn = false;
          isConnecting = false;
          isConnected = false;
          status = "Searching for devices...";
        });
      }
    });

    final currentState = await FlutterBluePlus.adapterState.first;
    if (currentState == BluetoothAdapterState.on) {
      setState(() => isBluetoothOn = true);
      startScan();
    } else {
      setState(() {
        status = "Searching for devices...";
        isBluetoothOn = false;
        isConnecting = false;
        isConnected = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((status) => !status.isGranted)) {
      developer.log("Bluetooth permissions not granted");
      setState(() {
        isConnecting = false;
        isConnected = false;
        status = "Searching for devices...";
      });
    }
  }

  Future<void> startScan() async {
    setState(() {
      isConnecting = true;
      deviceNotFound = false;
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    bool found = false;
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == deviceName) {
          found = true;
          setState(() {
            status =
                "Found Smart Parcel Box. Connecting to ${r.device.name}...";
          });
          await FlutterBluePlus.stopScan();
          await connectToDevice(r.device);
          break;
        }
      }
    });

    await Future.delayed(const Duration(seconds: 6));
    if (!found && mounted) {
      setState(() {
        isConnecting = false;
        deviceNotFound = true;
        status = "Searching for devices...";
      });
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false, license: License.free);
      connectedDevice = device;
      developer.log("Connected to ${device.name}");

      setState(() {
        status = "Connected to ${device.name}";
        isConnected = true;
      });

      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid == parcelBoxServiceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid == parcelBoxServiceSettingsCharUuid) {
              settingsChar = c;
              await readSettings();
            }
          }
        }
      }
    } catch (e) {
      developer.log("Connection failed: $e");
      setState(() {
        isConnected = false;
      });
    } finally {
      setState(() {
        isConnecting = false;
        status = "Searching for devices...";
      });
    }
  }

  Future<void> readSettings() async {
    if (settingsChar == null) return;
    try {
      List<int> value = await settingsChar!.read();
      String jsonString = utf8.decode(value);
      developer.log("Received settings JSON: $jsonString");
      Map<String, dynamic> parsed = jsonDecode(jsonString);
      setState(() {
        settings = parsed;
      });
    } catch (e) {
      developer.log("Failed to read settings: $e");
    }
  }

  Future<void> writeSettings() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      String jsonString = jsonEncode(settings);
      await settingsChar!.write(
        utf8.encode(jsonString),
        withoutResponse: false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Settings sent successfully!",
            style: TextStyle(
              color:
                  Provider.of<ThemeProvider>(
                        context,
                        listen: false,
                      ).currentThemeData !=
                      lightMode
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          backgroundColor:
              Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).currentThemeData !=
                  lightMode
              ? Colors.grey.shade900
              : Colors.grey.shade300,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      developer.log("Failed to send settings: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to send settings",
            style: TextStyle(
              color:
                  Provider.of<ThemeProvider>(
                        context,
                        listen: false,
                      ).currentThemeData !=
                      lightMode
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          backgroundColor:
              Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).currentThemeData !=
                  lightMode
              ? Colors.grey.shade900
              : Colors.grey.shade300,
        ),
      );
    }
  }

  InputDecoration _pillDecoration(String label) {
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(width: 2, color: Colors.grey.shade500),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(width: 2, color: Colors.grey.shade500),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(width: 3, color: Colors.lightBlue),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Widget buildSettingsForm() {
    if (settings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            ...settings.keys.map((key) {
              final value = settings[key];
              final isNumeric = value is num;
              final label =
                  friendlyLabels[key] ?? key.replaceAll('_', ' ').toUpperCase();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: TextFormField(
                  initialValue: value.toString(),
                  decoration: _pillDecoration(label),
                  keyboardType: isNumeric
                      ? const TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        )
                      : TextInputType.text,
                  maxLength: (key == "name" || key == "description")
                      ? 50
                      : null,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return "Required";
                    }

                    if (isNumeric) {
                      if (int.tryParse(val) == null) {
                        return "Value must be an integer";
                      }

                      if (int.parse(val) < 0 &&
                          (key != "minimal_temperature" &&
                              key != "maximal_temperature")) {
                        return "Value must be non-negative";
                      }

                      if ((key == "minimal_temperature" ||
                              key == "maximal_temperature") &&
                          (int.parse(val) < -40 || int.parse(val) > 80)) {
                        return "Temperature must be between -40°C and 80°C";
                      }

                      if ((key == "minimal_humidity" ||
                              key == "maximal_humidity") &&
                          (int.parse(val) < 0 || int.parse(val) > 100)) {
                        return "Humidity must be between 0% and 100%";
                      }

                      if (key == "ultrasonic_threshold" &&
                          (int.parse(val) < 5 || int.parse(val) > 60)) {
                        return "Distance must be between 5cm and 60cm";
                      }

                      if ((key == "autolock_slide_parcel_door_seconds" ||
                              key == "autolock_main_door_seconds" ||
                              key == "open_main_door_duration_seconds" ||
                              key == "courier_button_wait_time_seconds") &&
                          (int.parse(val) < 1 || int.parse(val) > 3600)) {
                        return "Value must be between 1 and 3600 seconds";
                      }

                      if (key == "data_publish_interval" &&
                          (int.parse(val) < 1 || int.parse(val) > 3600)) {
                        return "Value must be between 3 and 3600 seconds";
                      }

                      if (key == "status_publish_interval" &&
                          (int.parse(val) < 1 || int.parse(val) > 25)) {
                        return "Value must be between 1 and 25 seconds";
                      }
                    }

                    if ((key == "name" || key == "description") &&
                        val.length > 50) {
                      return "Maximum 50 characters allowed";
                    }

                    return null;
                  },
                  onSaved: (val) {
                    if (isNumeric) {
                      settings[key] = int.tryParse(val!) ?? 0;
                    } else {
                      settings[key] = val!;
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => writeSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.hardDriveUpload500, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    "Send Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBody() {
    if (!isBluetoothOn) {
      return buildBluetoothOff();
    } else if (isConnecting) {
      return buildConnecting();
    } else if (deviceNotFound) {
      return buildNotConnected();
    } else if (!isConnected) {
      return buildNotConnected();
    } else {
      return buildSettingsForm();
    }
  }

  Widget buildBluetoothOff() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bluetoothOff, color: Colors.red, size: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              "No Bluetooth",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              "Your device doesn't have Bluetooth enabled. Please turn on Bluetooth to connect to the Smart Parcel Box.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () => FlutterBluePlus.turnOn(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(LucideIcons.power500, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Turn On Bluetooth",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildConnecting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bluetoothSearching, color: Colors.blue, size: 50),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNotConnected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.circleAlert, color: Colors.red, size: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              "Not connected",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              "Your device didn't find the Smart Parcel Box. Please ensure it is powered on and within range.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () => startScan(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(LucideIcons.refreshCcw500, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Retry",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  "Settings",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Ink(
                  child: IconButton(
                    icon:
                        Provider.of<ThemeProvider>(context).currentThemeData ==
                            lightMode
                        ? Icon(LucideIcons.moon500, size: 25)
                        : Icon(LucideIcons.sun500, size: 25),
                    onPressed: () {
                      Provider.of<ThemeProvider>(
                        context,
                        listen: false,
                      ).toggleTheme();
                    },
                  ),
                ),
                Ink(
                  child: isConnecting
                      ? Icon(
                          LucideIcons.bluetoothSearching500,
                          size: 25,
                          color: Colors.blue,
                        )
                      : (isConnected
                            ? Icon(
                                LucideIcons.bluetoothConnected500,
                                size: 25,
                                color: Colors.green,
                              )
                            : Icon(
                                LucideIcons.bluetoothOff500,
                                size: 25,
                                color: Colors.red,
                              )),
                ),
              ],
            ),
          ],
        ),
      ),
      body: buildBody(),
    );
  }

  @override
  void dispose() {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      developer.log("Error stopping scan: $e");
    }

    if (connectedDevice != null) {
      try {
        connectedDevice!.disconnect();
        developer.log("Disconnected from ${connectedDevice!.name}");
      } catch (e) {
        developer.log("Error during disconnection: $e");
      }
    }

    super.dispose();
  }
}
