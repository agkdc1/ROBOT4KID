import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tank_state.dart';

class ButtonPanel extends StatelessWidget {
  const ButtonPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.local_fire_department,
          label: 'FIRE',
          color: Colors.red,
          onPressed: () {
            // Send fire command
          },
        ),
        const SizedBox(width: 12),
        _ControlButton(
          icon: Icons.camera_alt,
          label: 'CAMERA',
          color: Colors.blue,
          onPressed: () {
            context.read<TankState>().toggleCamera();
          },
        ),
        const SizedBox(width: 12),
        _ControlButton(
          icon: Icons.inventory,
          label: 'RESUPPLY',
          color: Colors.green,
          onPressed: () {},
        ),
        const SizedBox(width: 12),
        _ControlButton(
          icon: Icons.build,
          label: 'SPARE',
          color: Colors.orange,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
