import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fcs_state.dart';

class ButtonPanel extends StatelessWidget {
  final VoidCallback? onFire;
  final VoidCallback? onCameraToggle;
  final VoidCallback? onFcsToggle;
  final VoidCallback? onSpare;

  const ButtonPanel({
    super.key,
    this.onFire,
    this.onCameraToggle,
    this.onFcsToggle,
    this.onSpare,
  });

  @override
  Widget build(BuildContext context) {
    final fcs = context.watch<FcsState>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.local_fire_department,
          label: 'FIRE (A)',
          color: Colors.red,
          onPressed: onFire,
        ),
        const SizedBox(width: 12),
        _ControlButton(
          icon: Icons.camera_alt,
          label: 'VIEW (B)',
          color: Colors.blue,
          onPressed: onCameraToggle,
        ),
        const SizedBox(width: 12),
        _ControlButton(
          icon: Icons.gps_fixed,
          label: fcs.fcsActive ? 'FCS ON' : 'FCS (X)',
          color: fcs.fcsActive ? Colors.greenAccent : Colors.amber,
          onPressed: onFcsToggle,
        ),
        const SizedBox(width: 12),
        _ControlButton(
          icon: Icons.build,
          label: 'SPARE (Y)',
          color: Colors.orange,
          onPressed: onSpare,
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
