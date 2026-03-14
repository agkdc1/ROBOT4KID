import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tank_state.dart';
import '../models/app_config.dart';
import '../models/fcs_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TankState>();
    final config = context.watch<AppConfig>();
    final fcs = context.watch<FcsState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tablet config
          _SectionCard(
            title: 'Tablet',
            children: [
              _EditableTile(
                title: 'Model',
                value: config.tabletModel,
                onChanged: (v) {
                  config.tabletModel = v;
                  config.save();
                },
              ),
              _EditableTile(
                title: 'Connector',
                value: config.tabletConnector,
                onChanged: (v) {
                  config.tabletConnector = v;
                  config.save();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Connection
          _SectionCard(
            title: 'Connection',
            children: [
              _EditableTile(
                title: 'Hull IP',
                value: config.hullIp,
                onChanged: (v) {
                  config.hullIp = v;
                  config.save();
                },
              ),
              _EditableTile(
                title: 'Turret IP',
                value: config.turretIp,
                onChanged: (v) {
                  config.turretIp = v;
                  config.save();
                },
              ),
              _EditableTile(
                title: 'Server URL',
                value: config.serverUrl,
                onChanged: (v) {
                  config.serverUrl = v;
                  config.save();
                },
              ),
              ListTile(
                title: const Text('Status'),
                trailing: Icon(
                  state.connected ? Icons.circle : Icons.circle_outlined,
                  color: state.connected ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // FCS
          _SectionCard(
            title: 'Fire Control System',
            children: [
              SwitchListTile(
                title: const Text('FCS Active'),
                value: fcs.fcsActive,
                onChanged: (_) => fcs.toggleFcs(),
              ),
              _NumberTile(
                title: 'Ball Speed (m/s)',
                value: config.ballSpeedMs,
                onChanged: (v) {
                  config.ballSpeedMs = v;
                  config.save();
                },
              ),
              _NumberTile(
                title: 'Hop-Up RPM',
                value: config.hopUpRpm,
                onChanged: (v) {
                  config.hopUpRpm = v;
                  config.save();
                },
              ),
              ListTile(
                title: const Text('Computed Barrel Angle'),
                trailing: Text('${fcs.computedBarrelAngle.toStringAsFixed(1)}°'),
              ),
              ListTile(
                title: const Text('Shot History'),
                trailing: Text('${fcs.shotHistory.length} shots'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Diagnostics
          _SectionCard(
            title: 'Diagnostics',
            children: [
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
                trailing: Text('${state.heading.toStringAsFixed(1)}°'),
              ),
              ListTile(
                title: const Text('Turret Angle'),
                trailing: Text('${state.turretAngle}°'),
              ),
              ListTile(
                title: const Text('Barrel Elevation'),
                trailing: Text('${state.barrelElevation}°'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Default project
          _SectionCard(
            title: 'Default Project',
            children: [
              SwitchListTile(
                title: const Text('Skip project selection'),
                subtitle: config.defaultProjectId != null
                    ? Text('Default: ${config.defaultProjectId}')
                    : null,
                value: config.skipProjectSelection,
                onChanged: (v) {
                  config.skipProjectSelection = v;
                  if (!v) config.defaultProjectId = null;
                  config.save();
                  config.notifyListeners();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _EditableTile extends StatelessWidget {
  final String title;
  final String value;
  final ValueChanged<String> onChanged;

  const _EditableTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit, size: 18, color: Colors.white38),
      onTap: () async {
        final controller = TextEditingController(text: value);
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  child: const Text('Save')),
            ],
          ),
        );
        if (result != null && result.isNotEmpty) onChanged(result);
      },
    );
  }
}

class _NumberTile extends StatelessWidget {
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumberTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value.toStringAsFixed(1)),
      trailing: const Icon(Icons.edit, size: 18, color: Colors.white38),
      onTap: () async {
        final controller =
            TextEditingController(text: value.toStringAsFixed(1));
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  child: const Text('Save')),
            ],
          ),
        );
        if (result != null) {
          final parsed = double.tryParse(result);
          if (parsed != null) onChanged(parsed);
        }
      },
    );
  }
}
