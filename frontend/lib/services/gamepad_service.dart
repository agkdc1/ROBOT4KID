import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Physical USB gamepad support (2 analog sticks + 4 buttons).
/// Uses Flutter's RawKeyboardListener / HardwareKeyboard for gamepad events.
class GamepadService {
  // Stick axes (normalized -1.0 to 1.0)
  double leftX = 0, leftY = 0;
  double rightX = 0, rightY = 0;

  // Button states
  bool buttonA = false; // Fire
  bool buttonB = false; // Camera toggle
  bool buttonX = false; // FCS toggle
  bool buttonY = false; // Spare

  // Callbacks
  void Function(double x, double y)? onLeftStick;
  void Function(double x, double y)? onRightStick;
  void Function(GamepadButton button)? onButtonDown;
  void Function(GamepadButton button)? onButtonUp;

  // Deadzone
  static const double deadzone = 0.15;

  /// Process a raw key event from the gamepad.
  /// Android maps gamepad axes as AXIS_X, AXIS_Y, AXIS_Z, AXIS_RZ.
  bool handleKeyEvent(KeyEvent event) {
    // Gamepad buttons come as logical keys
    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      final button = _mapButton(key);
      if (button != null) {
        _setButton(button, true);
        onButtonDown?.call(button);
        return true;
      }
    } else if (event is KeyUpEvent) {
      final button = _mapButton(key);
      if (button != null) {
        _setButton(button, false);
        onButtonUp?.call(button);
        return true;
      }
    }

    return false;
  }

  /// Process gamepad axis motion (called from platform channel or pointer events).
  void updateAxis(int axis, double value) {
    // Apply deadzone
    if (value.abs() < deadzone) value = 0;

    switch (axis) {
      case 0: // AXIS_X — left stick horizontal
        leftX = value;
        onLeftStick?.call(leftX, leftY);
      case 1: // AXIS_Y — left stick vertical
        leftY = -value; // Invert Y
        onLeftStick?.call(leftX, leftY);
      case 2: // AXIS_Z — right stick horizontal (or AXIS_RX on some pads)
        rightX = value;
        onRightStick?.call(rightX, rightY);
      case 3: // AXIS_RZ — right stick vertical (or AXIS_RY)
        rightY = -value;
        onRightStick?.call(rightX, rightY);
    }
  }

  GamepadButton? _mapButton(LogicalKeyboardKey key) {
    // Standard Android gamepad mapping
    if (key == LogicalKeyboardKey.gameButtonA) return GamepadButton.a;
    if (key == LogicalKeyboardKey.gameButtonB) return GamepadButton.b;
    if (key == LogicalKeyboardKey.gameButtonX) return GamepadButton.x;
    if (key == LogicalKeyboardKey.gameButtonY) return GamepadButton.y;
    // Also map shoulder buttons
    if (key == LogicalKeyboardKey.gameButtonLeft1) return GamepadButton.a; // Fire
    if (key == LogicalKeyboardKey.gameButtonRight1) return GamepadButton.b;
    return null;
  }

  void _setButton(GamepadButton button, bool pressed) {
    switch (button) {
      case GamepadButton.a:
        buttonA = pressed;
      case GamepadButton.b:
        buttonB = pressed;
      case GamepadButton.x:
        buttonX = pressed;
      case GamepadButton.y:
        buttonY = pressed;
    }
  }
}

enum GamepadButton { a, b, x, y }
