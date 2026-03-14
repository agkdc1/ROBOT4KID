import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tank_state.dart';

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TankState>();

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top center — HUD data
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HudItem(label: 'SPD', value: '${((state.leftMotorSpeed + state.rightMotorSpeed) / 2).abs().round()}%'),
                    const SizedBox(width: 24),
                    _HudItem(label: 'HDG', value: '${state.heading.toStringAsFixed(0)} deg'),
                    const SizedBox(width: 24),
                    _HudItem(label: 'RNG', value: '${(state.rangeMm / 10.0).toStringAsFixed(1)}cm'),
                    const SizedBox(width: 24),
                    _HudItem(label: 'ELEV', value: '${state.barrelElevation} deg'),
                    const SizedBox(width: 24),
                    _HudItem(
                      label: 'BAT',
                      value: '${state.batteryPct}%',
                      color: state.batteryPct < 20 ? Colors.red : Colors.cyan,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Connection status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    state.connected ? Icons.wifi : Icons.wifi_off,
                    color: state.connected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.connected ? 'CONNECTED' : 'DISCONNECTED',
                    style: TextStyle(
                      color: state.connected ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudItem({
    required this.label,
    required this.value,
    this.color = Colors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
