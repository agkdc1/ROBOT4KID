import 'package:flutter/foundation.dart';

class TankState extends ChangeNotifier {
  // Connection
  bool connected = false;
  String hullIp = '192.168.4.1';
  String turretIp = '192.168.4.2';

  // Drive controls
  double throttle = 0.0;   // -1.0 to 1.0
  double steering = 0.0;   // -1.0 to 1.0
  int leftMotorSpeed = 0;  // -100 to 100
  int rightMotorSpeed = 0; // -100 to 100

  // Turret controls
  double turretX = 0.0;    // -1.0 to 1.0 (rotation)
  double turretY = 0.0;    // -1.0 to 1.0 (elevation)
  int turretAngle = 0;     // 0-360 degrees
  int barrelElevation = 0; // -10 to 45 degrees

  // Sensor data
  double heading = 0.0;    // degrees
  double pitch = 0.0;
  double roll = 0.0;
  int rangeMm = 0;         // ToF reading
  int batteryPct = 100;

  // Camera
  int cameraMode = 0;      // 0=driver, 1=gunner, 2=split

  void updateDrive(double x, double y) {
    throttle = y;
    steering = x;

    // Differential mixing
    double left = throttle + steering;
    double right = throttle - steering;

    // Normalize
    double maxMag = [left.abs(), right.abs(), 1.0].reduce((a, b) => a > b ? a : b);
    left /= maxMag;
    right /= maxMag;

    leftMotorSpeed = (left * 100).round().clamp(-100, 100);
    rightMotorSpeed = (right * 100).round().clamp(-100, 100);

    notifyListeners();
  }

  void updateTurret(double x, double y) {
    turretX = x;
    turretY = y;

    // Map to turret angle and elevation
    turretAngle = (turretAngle + (x * 5).round()) % 360;
    if (turretAngle < 0) turretAngle += 360;
    barrelElevation = (barrelElevation + (y * 2).round()).clamp(-10, 45);

    notifyListeners();
  }

  void updateSensors({
    double? heading,
    double? pitch,
    double? roll,
    int? rangeMm,
    int? batteryPct,
  }) {
    if (heading != null) this.heading = heading;
    if (pitch != null) this.pitch = pitch;
    if (roll != null) this.roll = roll;
    if (rangeMm != null) this.rangeMm = rangeMm;
    if (batteryPct != null) this.batteryPct = batteryPct;
    notifyListeners();
  }

  void setConnected(bool value) {
    connected = value;
    notifyListeners();
  }

  void toggleCamera() {
    cameraMode = (cameraMode + 1) % 3;
    notifyListeners();
  }
}
