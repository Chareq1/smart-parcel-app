class ParcelBoxData {
  bool doorState = false;
  int parcelCount = 0;
  bool isSpaceAvailable = true;
  bool mainDoorElectromagneticLock = true;
  double temperature = 0.0;
  bool parcelDoorStepMotorLock = true;
  int humidity = 0;


  ParcelBoxData({
    required this.doorState,
    required this.parcelCount,
    required this.isSpaceAvailable,
    required this.mainDoorElectromagneticLock,
    required this.temperature,
    required this.parcelDoorStepMotorLock,
    required this.humidity,
  });


  factory ParcelBoxData.fromJson(Map<String, dynamic> json) {
    return ParcelBoxData(
      doorState: (json['door_state'] ?? false) as bool,
      parcelCount: (json['parcel_count'] ?? 0) as int,
      isSpaceAvailable: (json['is_space_available'] ?? false) as bool,
      mainDoorElectromagneticLock: (json['main_door_electromagnetic_lock_state'] ?? true) as bool,
      parcelDoorStepMotorLock: (json['parcel_door_step_motor_lock_state'] ?? true) as bool,
      temperature: (json['temperature'] ?? 0.0) is num ? (json['temperature'] ?? 0.0).toDouble() : 0.0,
      humidity: (json['humidity'] ?? 0) is num ? (json['humidity'] ?? 0).toInt() : 0,
    );
  }
}