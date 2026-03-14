import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/train_state.dart';
import '../models/app_config.dart';
import '../models/command.dart';
import '../services/train_connection.dart';
import '../widgets/camera_view.dart';

class TrainControlScreen extends StatefulWidget {
  const TrainControlScreen({super.key});

  @override
  State<TrainControlScreen> createState() => _TrainControlScreenState();
}

class _TrainControlScreenState extends State<TrainControlScreen> {
  late TrainConnection _connection;

  @override
  void initState() {
    super.initState();

    final config = context.read<AppConfig>();
    final state = context.read<TrainState>();

    _connection = TrainConnection(
      trainIp: config.trainIp,
      port: config.wsPort,
      onConnectionChanged: (connected) {
        state.setConnected(connected);
      },
      onDataReceived: _handleTelemetry,
    );

    _connection.connect();

    // Start 20Hz command stream
    _connection.startCommandStream(() {
      return TrainCommand(
        type: TrainCommand.cmdDrive,
        speed: state.speed,
        horn: state.horn ? 1 : 0,
        lights: state.lights,
      );
    });
  }

  void _handleTelemetry(Uint8List data) {
    // TrainStatus packet: 6 bytes [header, type, speed, horn, lights, battery]
    if (data.length < 6 || data[0] != 0xAA) return;

    final state = context.read<TrainState>();
    state.updateSensors(batteryPct: data[5]);
  }

  @override
  void dispose() {
    _connection.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainState>();
    final config = context.read<AppConfig>();
    final streamUrl = 'http://${config.trainIp}:${config.streamPort}/stream';

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen camera feed (single MJPEG stream)
          Positioned.fill(
            child: MjpegView(streamUrl: streamUrl),
          ),

          // Speed gauge (top center)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: _SpeedGauge(speed: state.speed),
            ),
          ),

          // Battery indicator (top right)
          Positioned(
            top: 16,
            right: 60,
            child: _BatteryIndicator(batteryPct: state.batteryPct),
          ),

          // Connection indicator (top right, beside battery)
          Positioned(
            top: 16,
            right: 16,
            child: Icon(
              state.connected ? Icons.wifi : Icons.wifi_off,
              color: state.connected
                  ? Colors.lightBlueAccent
                  : Colors.red.shade300,
              size: 24,
            ),
          ),

          // Settings button (top right corner)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white54),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),

          // Vertical speed slider (left side) — throttle lever
          Positioned(
            left: 32,
            top: 80,
            bottom: 80,
            child: _ThrottleLever(
              speed: state.speed,
              onChanged: (value) {
                state.updateSpeed(value / 100.0);
              },
            ),
          ),

          // Lights toggle button (bottom center)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _LightsButton(
                lightsMode: state.lights,
                onPressed: () {
                  state.setLights((state.lights + 1) % 4);
                  _connection.sendCommand(
                    TrainCommand.setLights(state.lights),
                  );
                },
              ),
            ),
          ),

          // Horn button (large, bottom right)
          Positioned(
            bottom: 24,
            right: 40,
            child: _HornButton(
              active: state.horn,
              onTapDown: () {
                state.toggleHorn();
                _connection.sendCommand(TrainCommand.setHorn(true));
              },
              onTapUp: () {
                state.toggleHorn();
                _connection.sendCommand(TrainCommand.setHorn(false));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Analog-style speed gauge for train.
class _SpeedGauge extends StatelessWidget {
  final int speed;

  const _SpeedGauge({required this.speed});

  @override
  Widget build(BuildContext context) {
    final absSpeed = speed.abs();
    final direction = speed > 0
        ? 'FWD'
        : speed < 0
            ? 'REV'
            : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.lightBlueAccent.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.train, color: Colors.lightBlueAccent, size: 20),
          const SizedBox(width: 12),
          Text(
            '$absSpeed',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                direction,
                style: TextStyle(
                  fontSize: 12,
                  color: speed == 0
                      ? Colors.white38
                      : Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'km/h',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Battery indicator with blue/silver train theme.
class _BatteryIndicator extends StatelessWidget {
  final int batteryPct;

  const _BatteryIndicator({required this.batteryPct});

  @override
  Widget build(BuildContext context) {
    final color = batteryPct > 50
        ? Colors.lightBlueAccent
        : batteryPct > 20
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            batteryPct > 80
                ? Icons.battery_full
                : batteryPct > 50
                    ? Icons.battery_5_bar
                    : batteryPct > 20
                        ? Icons.battery_3_bar
                        : Icons.battery_1_bar,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$batteryPct%',
            style: TextStyle(color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Vertical throttle lever with train styling.
class _ThrottleLever extends StatelessWidget {
  final int speed;
  final ValueChanged<double> onChanged;

  const _ThrottleLever({
    required this.speed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blueGrey.shade600.withValues(alpha: 0.5),
        ),
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            activeTrackColor: Colors.lightBlueAccent,
            inactiveTrackColor: Colors.blueGrey.shade700,
            thumbColor: Colors.white,
            overlayColor: Colors.lightBlueAccent.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: speed.toDouble(),
            min: -100,
            max: 100,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Horn button — press and hold.
class _HornButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _HornButton({
    required this.active,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapUp,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? Colors.amber.shade700
              : Colors.blueGrey.shade800,
          border: Border.all(
            color: active
                ? Colors.amber
                : Colors.blueGrey.shade500,
            width: 3,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volume_up,
              color: active ? Colors.white : Colors.white54,
              size: 28,
            ),
            Text(
              'HORN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lights toggle button — cycles through 4 modes.
class _LightsButton extends StatelessWidget {
  final int lightsMode;
  final VoidCallback onPressed;

  const _LightsButton({
    required this.lightsMode,
    required this.onPressed,
  });

  static const _labels = ['OFF', 'LOW', 'HIGH', 'STROBE'];

  @override
  Widget build(BuildContext context) {
    final isOn = lightsMode > 0;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isOn ? Icons.lightbulb : Icons.lightbulb_outline,
        color: isOn ? Colors.amber : Colors.white54,
      ),
      label: Text(
        _labels[lightsMode],
        style: TextStyle(
          color: isOn ? Colors.amber : Colors.white54,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey.shade800,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isOn
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.blueGrey.shade600,
          ),
        ),
      ),
    );
  }
}
