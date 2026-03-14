import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tank_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TankState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Hull IP'),
                    subtitle: Text(state.hullIp),
                    trailing: Icon(
                      state.connected ? Icons.circle : Icons.circle_outlined,
                      color: state.connected ? Colors.green : Colors.red,
                    ),
                  ),
                  ListTile(
                    title: const Text('Turret IP'),
                    subtitle: Text(state.turretIp),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Diagnostics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Battery'),
                    trailing: Text('${state.batteryPct}%'),
                  ),
                  ListTile(
                    title: const Text('Range'),
                    trailing: Text('${state.rangeMm}mm'),
                  ),
                  ListTile(
                    title: const Text('Heading'),
                    trailing: Text('${state.heading.toStringAsFixed(1)} deg'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
