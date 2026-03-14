import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/tank_state.dart';
import '../models/fcs_state.dart';
import '../models/app_config.dart';
import '../services/gamepad_service.dart';
import '../services/tank_connection.dart';
import '../services/fcs_server_client.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/button_panel.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/camera_view.dart';
import '../widgets/crosshair_overlay.dart';
import '../models/command.dart';
import 'train_control_screen.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final projectId =
        ModalRoute.of(context)?.settings.arguments as String? ??
            config.defaultProjectId;
    final modelType = config.modelTypeForProject(projectId);

    if (modelType == 'train') {
      return const TrainControlScreen();
    }
    return const TankControlScreen();
  }
}

class TankControlScreen extends StatefulWidget {
  const TankControlScreen({super.key});

  @override
  State<TankControlScreen> createState() => _TankControlScreenState();
}

class _TankControlScreenState extends State<TankControlScreen> {
  late TankConnection _connection;
  late GamepadService _gamepad;
  late FcsServerClient _fcsClient;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _gamepad = GamepadService();

    final config = context.read<AppConfig>();
    final state = context.read<TankState>();
    final fcs = context.read<FcsState>();

    _connection = TankConnection(
      hullIp: config.hullIp,
      port: config.wsPort,
      onConnectionChanged: (connected) {
        state.setConnected(connected);
      },
      onDataReceived: _handleTelemetry,
    );

    _fcsClient = FcsServerClient(serverUrl: config.serverUrl);

    // Set up gamepad callbacks
    _gamepad.onLeftStick = (x, y) => state.updateDrive(x, y);
    _gamepad.onRightStick = (x, y) {
      state.updateTurret(x, 0); // X = turret rotation
      fcs.updateCrosshair(fcs.crosshairOffsetY + y * 0.01); // Y = crosshair
    };
    _gamepad.onButtonDown = (button) {
      switch (button) {
        case GamepadButton.a:
          _handleFire(state, fcs, config);
        case GamepadButton.b:
          state.toggleCamera();
        case GamepadButton.x:
          fcs.toggleFcs();
        case GamepadButton.y:
          break; // Spare
      }
    };

    // Connect to tank
    _connection.connect();

    // Start 20Hz command stream
    _connection.startCommandStream(() {
      return TankCommand(
        type: TankCommand.cmdMove,
        leftSpeed: state.leftMotorSpeed,
        rightSpeed: state.rightMotorSpeed,
        turretAngle: state.turretAngle * 10,
        barrelElevation: state.barrelElevation,
        cameraMode: state.cameraMode,
      );
    });

    // Fetch latest FCS coefficients from server
    _fetchCoefficients(fcs);
  }

  Future<void> _fetchCoefficients(FcsState fcs) async {
    final coeffs = await _fcsClient.fetchCoefficients();
    if (coeffs != null) {
      fcs.updateCoefficients(coeffs);
    }
  }

  void _handleTelemetry(Uint8List data) {
    if (data.length < 11 || data[0] != 0xAA || data[1] != 0x05) return;

    final bd = ByteData.view(data.buffer);
    final state = context.read<TankState>();
    final fcs = context.read<FcsState>();
    final config = context.read<AppConfig>();

    state.updateSensors(
      heading: bd.getInt16(2, Endian.little) / 10.0,
      pitch: bd.getInt16(4, Endian.little) / 10.0,
      roll: bd.getInt16(6, Endian.little) / 10.0,
      rangeMm: bd.getUint16(8, Endian.little),
      batteryPct: bd.getUint8(10),
    );

    // Update FCS barrel angle based on range and conditions
    if (fcs.fcsActive && state.rangeMm > 0) {
      final angle = fcs.calculateBarrelAngle(
        rangeMeters: state.rangeMm / 1000.0,
        ballSpeedMs: config.ballSpeedMs,
        hopUpRpm: config.hopUpRpm,
        chassisSpeedMs: state.chassisSpeedMs,
        turretAngleDeg: state.turretAngle.toDouble(),
      );
      // Apply crosshair adjustment
      final adjusted = angle + fcs.crosshairToBarrelAdjustment();
      state.setBarrelElevation(adjusted.round());
    }
  }

  void _handleFire(TankState state, FcsState fcs, AppConfig config) {
    // Send fire command
    _connection.sendCommand(TankCommand.fire());

    // Record shot data for RL training
    fcs.recordShot(
      rangeMeters: state.rangeMm / 1000.0,
      barrelAngle: state.barrelElevation.toDouble(),
      ballSpeed: config.ballSpeedMs,
      hopUpRpm: config.hopUpRpm,
      chassisSpeed: state.chassisSpeedMs,
      turretAngle: state.turretAngle.toDouble(),
      actualImpactY: 0.0, // Will be updated via camera tracking
    );

    // Upload shot data every 5 shots
    if (fcs.shotHistory.length % 5 == 0) {
      _fcsClient.uploadShotData(fcs.shotHistory);
    }
  }

  @override
  void dispose() {
    _connection.disconnect();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TankState>();
    final config = context.read<AppConfig>();
    final fcs = context.watch<FcsState>();

    final hullStreamUrl = 'http://${config.hullIp}:${config.streamPort}/stream';
    final turretStreamUrl = 'http://${config.turretIp}:${config.streamPort}/stream';

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _gamepad.handleKeyEvent,
      child: Scaffold(
        body: Stack(
          children: [
            // Camera feeds with PIP
            CameraWithPip(
              mainStreamUrl: hullStreamUrl,
              pipStreamUrl: turretStreamUrl,
              swapped: state.cameraSwapped,
            ),

            // Crosshair overlay (shown on turret main view or always)
            if (state.cameraSwapped || fcs.fcsActive)
              const CrosshairOverlay(),

            // HUD overlay
            const HudOverlay(),

            // Left joystick (drive) — virtual, used when no physical gamepad
            Positioned(
              left: 40,
              bottom: 80,
              child: JoystickWidget(
                label: 'DRIVE',
                onChanged: (x, y) {
                  context.read<TankState>().updateDrive(x, y);
                },
              ),
            ),

            // Right joystick (turret horizontal + crosshair vertical)
            Positioned(
              right: 40,
              bottom: 80,
              child: JoystickWidget(
                label: 'TURRET',
                onChanged: (x, y) {
                  final tankState = context.read<TankState>();
                  final fcsState = context.read<FcsState>();
                  tankState.updateTurret(x, 0);
                  fcsState.updateCrosshair(
                    fcsState.crosshairOffsetY + y * 0.005,
                  );
                },
              ),
            ),

            // Button panel (bottom center)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: ButtonPanel(
                onFire: () => _handleFire(state, fcs, config),
                onCameraToggle: () => state.toggleCamera(),
                onFcsToggle: () => fcs.toggleFcs(),
              ),
            ),

            // Settings button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white54),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
