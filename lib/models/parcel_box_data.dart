class ParcelBoxData {
  bool doorState = false;
  int parcelCount = 0;
  double distance = 0.0;
  bool electromagneticLock = true;
  double temperatureCelsius = 0.0;
  double temperatureFahrenheit = 0.0;
  double humidity = 0.0;

  ParcelBoxData({
    required this.doorState,
    required this.parcelCount,
    required this.distance,
    required this.electromagneticLock,
    required this.temperatureCelsius,
    required this.temperatureFahrenheit,
    required this.humidity,
  });

  factory ParcelBoxData.fromJson(Map<String, dynamic> json) {
    return ParcelBoxData(
      doorState: (json['door_state'] ?? false) as bool,
      parcelCount: (json['parcel_count'] ?? 0) as int,
      distance: (json['distance'] ?? 0.0) is num ? (json['distance'] ?? 0.0).toDouble() : 0.0,
      electromagneticLock: (json['electromagnetic_lock_state'] ?? true) as bool,
      temperatureCelsius: (json['temperature_celsius'] ?? 0.0) is num ? (json['temperature_celsius'] ?? 0.0).toDouble() : 0.0,
      temperatureFahrenheit: (json['temperature_fahrenheit'] ?? 0.0) is num ? (json['temperature_fahrenheit'] ?? 0.0).toDouble() : 0.0,
      humidity: (json['humidity'] ?? 0.0) is num ? (json['humidity'] ?? 0.0).toDouble() : 0.0,
    );
  }
}