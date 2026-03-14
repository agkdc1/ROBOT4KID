import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configurable app settings — tablet, connection, defaults.
class AppConfig extends ChangeNotifier {
  // Tablet config
  String tabletModel = 'Galaxy Tab A 8.0 2019';
  String tabletConnector = 'USB Type-C';

  // Default project
  String? defaultProjectId;
  bool skipProjectSelection = false;

  // Connection
  String hullIp = '192.168.4.1';
  String turretIp = '192.168.4.2';
  int wsPort = 80;
  int streamPort = 81;
  String wifiSsid = 'TANK_CTRL';
  String wifiPassword = 'tank1234';

  // Server
  String serverUrl = 'http://192.168.1.100:8000';

  // FCS
  double ballSpeedMs = 15.0;       // m/s muzzle velocity
  double hopUpRpm = 3000.0;        // backspin RPM
  double ballMassGrams = 3.0;      // sponge ball mass
  double ballDiameterMm = 40.0;    // sponge ball diameter

  // Projects
  List<ProjectEntry> projects = [
    ProjectEntry(
      id: 'm1a1_tank',
      name: 'M1A1 Abrams Tank',
      description: '1/10 scale tank with dual ESP32-CAM',
      icon: 'military_tech',
    ),
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    defaultProjectId = prefs.getString('defaultProjectId');
    skipProjectSelection = prefs.getBool('skipProjectSelection') ?? false;
    hullIp = prefs.getString('hullIp') ?? hullIp;
    turretIp = prefs.getString('turretIp') ?? turretIp;
    serverUrl = prefs.getString('serverUrl') ?? serverUrl;
    tabletModel = prefs.getString('tabletModel') ?? tabletModel;
    tabletConnector = prefs.getString('tabletConnector') ?? tabletConnector;
    ballSpeedMs = prefs.getDouble('ballSpeedMs') ?? ballSpeedMs;
    hopUpRpm = prefs.getDouble('hopUpRpm') ?? hopUpRpm;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (defaultProjectId != null) {
      prefs.setString('defaultProjectId', defaultProjectId!);
    }
    prefs.setBool('skipProjectSelection', skipProjectSelection);
    prefs.setString('hullIp', hullIp);
    prefs.setString('turretIp', turretIp);
    prefs.setString('serverUrl', serverUrl);
    prefs.setString('tabletModel', tabletModel);
    prefs.setString('tabletConnector', tabletConnector);
    prefs.setDouble('ballSpeedMs', ballSpeedMs);
    prefs.setDouble('hopUpRpm', hopUpRpm);
  }

  void setDefaultProject(String? projectId, {bool skip = false}) {
    defaultProjectId = projectId;
    skipProjectSelection = skip;
    save();
    notifyListeners();
  }
}

class ProjectEntry {
  final String id;
  final String name;
  final String description;
  final String icon;

  const ProjectEntry({
    required this.id,
    required this.name,
    required this.description,
    this.icon = 'rocket_launch',
  });
}
