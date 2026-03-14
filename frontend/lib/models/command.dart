import 'dart:typed_data';

/// Command packet matching the ESP32 protocol.h TankCommand struct.
class TankCommand {
  static const int headerByte = 0xAA;
  static const int cmdMove = 0x01;
  static const int cmdTurret = 0x02;
  static const int cmdFire = 0x03;
  static const int cmdCamera = 0x04;

  final int type;
  final int leftSpeed;    // -100 to 100
  final int rightSpeed;   // -100 to 100
  final int turretAngle;  // 0-3600 (degrees x10)
  final int barrelElevation; // -10 to 45
  final int fire;         // 0 or 1
  final int cameraMode;   // 0, 1, or 2

  TankCommand({
    required this.type,
    this.leftSpeed = 0,
    this.rightSpeed = 0,
    this.turretAngle = 0,
    this.barrelElevation = 0,
    this.fire = 0,
    this.cameraMode = 0,
  });

  /// Serialize to bytes matching the C struct (with checksum).
  Uint8List toBytes() {
    final bytes = Uint8List(10);
    final data = ByteData.view(bytes.buffer);

    data.setUint8(0, headerByte);
    data.setUint8(1, type);
    data.setInt8(2, leftSpeed.clamp(-100, 100));
    data.setInt8(3, rightSpeed.clamp(-100, 100));
    data.setInt16(4, turretAngle.clamp(0, 3600), Endian.little);
    data.setInt8(6, barrelElevation.clamp(-10, 45));
    data.setUint8(7, fire.clamp(0, 1));
    data.setUint8(8, cameraMode.clamp(0, 2));

    // XOR checksum
    int checksum = 0;
    for (int i = 0; i < 9; i++) {
      checksum ^= bytes[i];
    }
    data.setUint8(9, checksum);

    return bytes;
  }

  /// Create a move command.
  factory TankCommand.move(int leftSpeed, int rightSpeed) {
    return TankCommand(
      type: cmdMove,
      leftSpeed: leftSpeed,
      rightSpeed: rightSpeed,
    );
  }

  /// Create a turret command.
  factory TankCommand.turret(int angle, int elevation) {
    return TankCommand(
      type: cmdTurret,
      turretAngle: angle * 10,
      barrelElevation: elevation,
    );
  }

  /// Create a fire command.
  factory TankCommand.fire() {
    return TankCommand(type: cmdFire, fire: 1);
  }
}
