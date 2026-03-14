import 'dart:math';
import 'package:flutter/foundation.dart';

/// Fire Control System state — crosshair, trajectory, barrel angle.
class FcsState extends ChangeNotifier {
  // Crosshair position (0.0 = center, range: -1/6 to +1/6 of screen height)
  double crosshairOffsetY = 0.0;

  // FCS engagement
  bool fcsActive = false;

  // Trajectory coefficients (updated from server via RL)
  TrajectoryCoefficients coefficients = TrajectoryCoefficients();

  // Last shot data (for server upload)
  List<ShotRecord> shotHistory = [];

  // Computed barrel angle from FCS
  double computedBarrelAngle = 0.0;

  /// Calculate barrel angle for given target distance and conditions.
  double calculateBarrelAngle({
    required double rangeMeters,
    required double ballSpeedMs,
    required double hopUpRpm,
    required double chassisSpeedMs,
    required double turretAngleDeg,
  }) {
    final c = coefficients;

    // Physics-based trajectory with tunable coefficients:
    // Angle = base_angle + gravity_comp + drag_comp + hopup_comp + motion_comp
    //
    // Base: arctan(g * range / (2 * v^2)) — simplified parabolic
    // Gravity compensation: c.gravityFactor * (range / v^2)
    // Drag compensation: c.dragFactor * range^2
    // Hop-up lift: c.hopUpFactor * hopUp / v
    // Chassis motion: c.motionFactor * chassisSpeed * cos(turretAngle)

    final g = 9.81 * c.gravityFactor;
    final v = ballSpeedMs;
    final r = rangeMeters;

    // Base parabolic angle (degrees)
    double angle = atan(g * r / (2 * v * v)) * (180 / pi);

    // Drag compensation (quadratic with range)
    angle += c.dragFactor * r * r;

    // Hop-up spin lift compensation (reduces needed angle)
    angle -= c.hopUpFactor * (hopUpRpm / 1000.0) / v;

    // Chassis motion compensation
    final turretRad = turretAngleDeg * pi / 180;
    angle += c.motionFactor * chassisSpeedMs * cos(turretRad);

    // Bias term (learned offset)
    angle += c.bias;

    computedBarrelAngle = angle.clamp(-10.0, 45.0);
    notifyListeners();
    return computedBarrelAngle;
  }

  /// Map crosshair vertical offset to barrel angle adjustment.
  /// Crosshair in middle 1/3 of view maps to barrel angle range.
  double crosshairToBarrelAdjustment() {
    // crosshairOffsetY range: -1/6 to +1/6 (middle 1/3 of view)
    // Maps to barrel angle adjustment: -5 to +5 degrees
    return crosshairOffsetY * 30.0; // 1/6 * 30 = 5 degrees
  }

  void updateCrosshair(double offsetY) {
    // Clamp to middle 1/3 of view
    crosshairOffsetY = offsetY.clamp(-1.0 / 6.0, 1.0 / 6.0);
    notifyListeners();
  }

  void recordShot({
    required double rangeMeters,
    required double barrelAngle,
    required double ballSpeed,
    required double hopUpRpm,
    required double chassisSpeed,
    required double turretAngle,
    required double actualImpactY, // observed vertical offset from target
  }) {
    shotHistory.add(ShotRecord(
      timestamp: DateTime.now(),
      rangeMeters: rangeMeters,
      barrelAngle: barrelAngle,
      ballSpeed: ballSpeed,
      hopUpRpm: hopUpRpm,
      chassisSpeed: chassisSpeed,
      turretAngle: turretAngle,
      actualImpactY: actualImpactY,
    ));
    notifyListeners();
  }

  void updateCoefficients(TrajectoryCoefficients newCoeffs) {
    coefficients = newCoeffs;
    notifyListeners();
  }

  void toggleFcs() {
    fcsActive = !fcsActive;
    notifyListeners();
  }
}

/// Tunable trajectory equation coefficients.
class TrajectoryCoefficients {
  final double gravityFactor;
  final double dragFactor;
  final double hopUpFactor;
  final double motionFactor;
  final double bias;

  const TrajectoryCoefficients({
    this.gravityFactor = 1.0,
    this.dragFactor = 0.001,
    this.hopUpFactor = 0.5,
    this.motionFactor = 0.1,
    this.bias = 0.0,
  });

  Map<String, double> toJson() => {
    'gravityFactor': gravityFactor,
    'dragFactor': dragFactor,
    'hopUpFactor': hopUpFactor,
    'motionFactor': motionFactor,
    'bias': bias,
  };

  factory TrajectoryCoefficients.fromJson(Map<String, dynamic> json) {
    return TrajectoryCoefficients(
      gravityFactor: (json['gravityFactor'] as num?)?.toDouble() ?? 1.0,
      dragFactor: (json['dragFactor'] as num?)?.toDouble() ?? 0.001,
      hopUpFactor: (json['hopUpFactor'] as num?)?.toDouble() ?? 0.5,
      motionFactor: (json['motionFactor'] as num?)?.toDouble() ?? 0.1,
      bias: (json['bias'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Record of a single shot for RL training.
class ShotRecord {
  final DateTime timestamp;
  final double rangeMeters;
  final double barrelAngle;
  final double ballSpeed;
  final double hopUpRpm;
  final double chassisSpeed;
  final double turretAngle;
  final double actualImpactY;

  const ShotRecord({
    required this.timestamp,
    required this.rangeMeters,
    required this.barrelAngle,
    required this.ballSpeed,
    required this.hopUpRpm,
    required this.chassisSpeed,
    required this.turretAngle,
    required this.actualImpactY,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'range_meters': rangeMeters,
    'barrel_angle': barrelAngle,
    'ball_speed': ballSpeed,
    'hopup_rpm': hopUpRpm,
    'chassis_speed': chassisSpeed,
    'turret_angle': turretAngle,
    'actual_impact_y': actualImpactY,
  };
}
