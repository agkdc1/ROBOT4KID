import 'package:flutter/foundation.dart';

/// State for train control — simpler than TankState (no turret, no FCS).
class TrainState extends ChangeNotifier {
  // Connection
  bool connected = false;
  String trainIp = '192.168.4.1';

  // Drive
  int speed = 0; // -100 to 100

  // Accessories
  bool horn = false;
  int lights = 0; // 0-3 (off, low, high, strobe)

  // Sensor data
  int batteryPct = 100;

  // Camera — single camera only
  int cameraMode = 0;

  // Active project
  String activeProjectId = 'shinkansen_n700';

  /// Map joystick Y axis (-1.0..1.0) to speed (-100..100).
  void updateSpeed(double y) {
    speed = (y * 100).round().clamp(-100, 100);
    notifyListeners();
  }

  void toggleHorn() {
    horn = !horn;
    notifyListeners();
  }

  void setLights(int mode) {
    lights = mode.clamp(0, 3);
    notifyListeners();
  }

  void setConnected(bool value) {
    connected = value;
    notifyListeners();
  }

  void updateSensors({int? batteryPct}) {
    if (batteryPct != null) this.batteryPct = batteryPct;
    notifyListeners();
  }
}
