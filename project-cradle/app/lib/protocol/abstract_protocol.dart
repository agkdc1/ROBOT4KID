import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

// =============================================================================
// Abstract Communication Protocol Layer
// =============================================================================
//
// The universal cradle does NOT know what robot it controls.
// It only knows HOW to exchange state over two tracks:
//
//   Track A: WebSocket  -- Control (uplink) & Telemetry (downlink)
//   Track B: HTTP       -- MJPEG video stream (one-way, ESP -> Pi)
//
// Any robot that speaks this protocol can be controlled by any cradle.
// =============================================================================

// ---------------------------------------------------------------------------
// InputState  (Pi -> ESP, 30 Hz uplink)
// ---------------------------------------------------------------------------

/// Normalised input captured from the physical cradle controls.
/// All axis values are clamped to [-1.0, 1.0].
/// All buttons are simple booleans (pressed / released).
class InputState {
  /// Left stick horizontal axis. -1.0 = full left, 1.0 = full right.
  final double joyLeftX;

  /// Left stick vertical axis. -1.0 = full down, 1.0 = full up.
  final double joyLeftY;

  /// Right stick horizontal axis. -1.0 = full left, 1.0 = full right.
  final double joyRightX;

  /// Right stick vertical axis. -1.0 = full down, 1.0 = full up.
  final double joyRightY;

  /// Right-stick trigger (analog click or dedicated trigger button).
  final bool trigger;

  /// Face button A (primary action / fire).
  final bool btnA;

  /// Face button B (secondary action / view toggle).
  final bool btnB;

  /// Face button C (tertiary action / mode switch).
  final bool btnC;

  /// Face button D (quaternary action / spare).
  final bool btnD;

  /// Monotonically increasing sequence number (wraps at 2^32).
  final int seq;

  /// Timestamp in milliseconds since epoch (Pi clock).
  final int timestampMs;

  const InputState({
    this.joyLeftX = 0.0,
    this.joyLeftY = 0.0,
    this.joyRightX = 0.0,
    this.joyRightY = 0.0,
    this.trigger = false,
    this.btnA = false,
    this.btnB = false,
    this.btnC = false,
    this.btnD = false,
    this.seq = 0,
    this.timestampMs = 0,
  });

  /// Clamp a raw axis value to [-1.0, 1.0].
  static double _clamp(double v) => v.clamp(-1.0, 1.0);

  /// Construct from a decoded JSON map (e.g. for unit tests / replay).
  factory InputState.fromJson(Map<String, dynamic> json) {
    return InputState(
      joyLeftX: _clamp((json['jlx'] as num?)?.toDouble() ?? 0.0),
      joyLeftY: _clamp((json['jly'] as num?)?.toDouble() ?? 0.0),
      joyRightX: _clamp((json['jrx'] as num?)?.toDouble() ?? 0.0),
      joyRightY: _clamp((json['jry'] as num?)?.toDouble() ?? 0.0),
      trigger: json['trg'] as bool? ?? false,
      btnA: json['a'] as bool? ?? false,
      btnB: json['b'] as bool? ?? false,
      btnC: json['c'] as bool? ?? false,
      btnD: json['d'] as bool? ?? false,
      seq: json['seq'] as int? ?? 0,
      timestampMs: json['ts'] as int? ?? 0,
    );
  }

  /// Compact JSON keys to minimise WebSocket frame size.
  Map<String, dynamic> toJson() => {
        'jlx': joyLeftX,
        'jly': joyLeftY,
        'jrx': joyRightX,
        'jry': joyRightY,
        'trg': trigger,
        'a': btnA,
        'b': btnB,
        'c': btnC,
        'd': btnD,
        'seq': seq,
        'ts': timestampMs,
      };

  /// Convenience: encode directly to a JSON string.
  String encode() => jsonEncode(toJson());

  @override
  String toString() =>
      'InputState(L[$joyLeftX,$joyLeftY] R[$joyRightX,$joyRightY] '
      'trg=$trigger A=$btnA B=$btnB C=$btnC D=$btnD seq=$seq)';
}

// ---------------------------------------------------------------------------
// RobotStatus  (ESP -> Pi, downlink at up to 30 Hz)
// ---------------------------------------------------------------------------

/// Hardware telemetry reported by the connected robot.
/// The [extra] map allows any robot to publish model-specific data without
/// changing the protocol definition.
class RobotStatus {
  /// Number of ESP32 nodes currently communicating (e.g. hull + turret = 2).
  final int espsConnected;

  /// Main battery voltage in volts (0.0 if unknown).
  final double batteryVoltage;

  /// Battery percentage estimate (0-100, null if unknown).
  final int? batteryPercent;

  /// IMU / gyroscope readings: {pitch, roll, yaw} in degrees.
  final Map<String, double> gyro;

  /// Ultrasonic / ToF distance reading in centimetres (null if no sensor).
  final double? ultrasonicCm;

  /// Wi-Fi RSSI in dBm (null if unavailable).
  final int? rssi;

  /// Free heap bytes on the primary ESP32 (null if unreported).
  final int? freeHeap;

  /// Robot-specific extension payload.  Any key-value pairs the robot
  /// firmware wants to surface (e.g. turret angle, track RPM, horn state).
  final Map<String, dynamic> extra;

  /// Timestamp in milliseconds since epoch (ESP clock, may drift).
  final int timestampMs;

  const RobotStatus({
    this.espsConnected = 0,
    this.batteryVoltage = 0.0,
    this.batteryPercent,
    this.gyro = const {},
    this.ultrasonicCm,
    this.rssi,
    this.freeHeap,
    this.extra = const {},
    this.timestampMs = 0,
  });

  factory RobotStatus.fromJson(Map<String, dynamic> json) {
    final rawGyro = json['gyro'] as Map<String, dynamic>? ?? {};
    final gyro = rawGyro.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return RobotStatus(
      espsConnected: json['esps'] as int? ?? 0,
      batteryVoltage: (json['bat_v'] as num?)?.toDouble() ?? 0.0,
      batteryPercent: json['bat_pct'] as int?,
      gyro: gyro,
      ultrasonicCm: (json['dist_cm'] as num?)?.toDouble(),
      rssi: json['rssi'] as int?,
      freeHeap: json['heap'] as int?,
      extra: json['extra'] as Map<String, dynamic>? ?? {},
      timestampMs: json['ts'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'esps': espsConnected,
        'bat_v': batteryVoltage,
        if (batteryPercent != null) 'bat_pct': batteryPercent,
        'gyro': gyro,
        if (ultrasonicCm != null) 'dist_cm': ultrasonicCm,
        if (rssi != null) 'rssi': rssi,
        if (freeHeap != null) 'heap': freeHeap,
        'extra': extra,
        'ts': timestampMs,
      };

  String encode() => jsonEncode(toJson());

  bool get hasBattery => batteryVoltage > 0.0;
  bool get hasGyro => gyro.isNotEmpty;
  bool get hasDistance => ultrasonicCm != null;

  @override
  String toString() =>
      'RobotStatus(esps=$espsConnected bat=${batteryVoltage}V '
      'gyro=$gyro dist=$ultrasonicCm extras=${extra.keys})';
}

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------

/// High-level connection lifecycle.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

// ---------------------------------------------------------------------------
// CradleProtocol  (the main interface)
// ---------------------------------------------------------------------------

/// Bidirectional communication channel between cradle and robot.
///
/// Usage:
/// ```dart
/// final proto = CradleProtocol(robotHost: '192.168.4.1');
/// await proto.connect();
/// proto.statusStream.listen((s) => print(s));
/// proto.sendInput(InputState(joyLeftY: 0.5));
/// ```
class CradleProtocol {
  // ---- configuration ----

  /// Robot IP (usually the ESP32 SoftAP gateway).
  final String robotHost;

  /// WebSocket port on the robot.
  final int wsPort;

  /// MJPEG stream port on the robot.
  final int mjpegPort;

  /// Target uplink rate in Hz.
  final int uplinkHz;

  /// Maximum number of automatic reconnection attempts.
  final int maxReconnectAttempts;

  /// Base delay between reconnection attempts (doubles each time).
  final Duration reconnectBaseDelay;

  // ---- internal state ----

  WebSocketChannel? _channel;
  StreamSubscription? _downlinkSub;
  Timer? _uplinkTimer;
  Timer? _heartbeatTimer;

  int _seq = 0;
  int _reconnectAttempts = 0;
  InputState _lastInput = const InputState();

  final StreamController<RobotStatus> _statusController =
      StreamController<RobotStatus>.broadcast();

  final StreamController<ConnectionState> _connectionController =
      StreamController<ConnectionState>.broadcast();

  ConnectionState _state = ConnectionState.disconnected;

  CradleProtocol({
    required this.robotHost,
    this.wsPort = 81,
    this.mjpegPort = 80,
    this.uplinkHz = 30,
    this.maxReconnectAttempts = 10,
    this.reconnectBaseDelay = const Duration(seconds: 1),
  });

  // ---- public API ----

  /// Current connection state.
  ConnectionState get state => _state;

  /// Stream of [RobotStatus] frames from the robot.
  Stream<RobotStatus> get statusStream => _statusController.stream;

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionStream => _connectionController.stream;

  /// URL for the MJPEG camera stream (Track B).
  String get mjpegUrl => 'http://$robotHost:$mjpegPort/stream';

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _state == ConnectionState.connected;

  /// Open the WebSocket connection and start the uplink timer.
  Future<void> connect() async {
    if (_state == ConnectionState.connected ||
        _state == ConnectionState.connecting) {
      return;
    }
    _setState(ConnectionState.connecting);
    _reconnectAttempts = 0;
    await _doConnect();
  }

  /// Gracefully close the connection.
  Future<void> disconnect() async {
    _uplinkTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _downlinkSub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  /// Queue an [InputState] to be sent on the next uplink tick.
  /// The most recent input always wins (no queue buildup).
  void sendInput(InputState input) {
    _lastInput = InputState(
      joyLeftX: input.joyLeftX,
      joyLeftY: input.joyLeftY,
      joyRightX: input.joyRightX,
      joyRightY: input.joyRightY,
      trigger: input.trigger,
      btnA: input.btnA,
      btnB: input.btnB,
      btnC: input.btnC,
      btnD: input.btnD,
      seq: _seq++,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Send a single [InputState] immediately (bypass the ticker).
  void sendInputNow(InputState input) {
    _lastInput = InputState(
      joyLeftX: input.joyLeftX,
      joyLeftY: input.joyLeftY,
      joyRightX: input.joyRightX,
      joyRightY: input.joyRightY,
      trigger: input.trigger,
      btnA: input.btnA,
      btnB: input.btnB,
      btnC: input.btnC,
      btnD: input.btnD,
      seq: _seq++,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    _transmit();
  }

  /// Release all resources.  Call this in the widget's dispose().
  void dispose() {
    disconnect();
    _statusController.close();
    _connectionController.close();
  }

  // ---- internals ----

  void _setState(ConnectionState s) {
    if (_state == s) return;
    _state = s;
    _connectionController.add(s);
  }

  Future<void> _doConnect() async {
    try {
      final uri = Uri.parse('ws://$robotHost:$wsPort/ws');
      _channel = WebSocketChannel.connect(uri);

      // Wait for the connection to be established.
      await _channel!.ready;

      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;

      // Start downlink listener.
      _downlinkSub = _channel!.stream.listen(
        _onDownlink,
        onError: _onError,
        onDone: _onDone,
      );

      // Start uplink ticker.
      final interval = Duration(milliseconds: (1000 / uplinkHz).round());
      _uplinkTimer = Timer.periodic(interval, (_) => _transmit());

      // Heartbeat: send a ping every 5 s to detect dead connections.
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _transmit(),
      );
    } catch (e) {
      _onError(e);
    }
  }

  void _transmit() {
    if (_channel == null || _state != ConnectionState.connected) return;
    try {
      _channel!.sink.add(_lastInput.encode());
    } catch (_) {
      // Will be caught by stream onError.
    }
  }

  void _onDownlink(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final status = RobotStatus.fromJson(json);
      _statusController.add(status);
    } catch (e) {
      // Malformed frame -- silently drop to keep the stream alive.
    }
  }

  void _onError(dynamic error) {
    _setState(ConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    if (_state == ConnectionState.disconnected) return;
    _setState(ConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _uplinkTimer?.cancel();
    _heartbeatTimer?.cancel();
    _downlinkSub?.cancel();
    _channel = null;

    if (_reconnectAttempts >= maxReconnectAttempts) {
      _setState(ConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    _setState(ConnectionState.reconnecting);

    // Exponential backoff: base * 2^(attempt-1), capped at 30 s.
    final delayMs = (reconnectBaseDelay.inMilliseconds *
            (1 << (_reconnectAttempts - 1)))
        .clamp(0, 30000);

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_state == ConnectionState.disconnected) return;
      _doConnect();
    });
  }
}
