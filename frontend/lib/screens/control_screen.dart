import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tank_state.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/button_panel.dart';
import '../widgets/hud_overlay.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background — camera feed placeholder
          Container(
            color: Colors.black,
            child: const Center(
              child: Text(
                'Camera Feed',
                style: TextStyle(color: Colors.white24, fontSize: 24),
              ),
            ),
          ),

          // HUD overlay
          const HudOverlay(),

          // Left joystick (drive)
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

          // Right joystick (turret)
          Positioned(
            right: 40,
            bottom: 80,
            child: JoystickWidget(
              label: 'TURRET',
              onChanged: (x, y) {
                context.read<TankState>().updateTurret(x, y);
              },
            ),
          ),

          // Button panel (bottom center)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: ButtonPanel(),
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
    );
  }
}
