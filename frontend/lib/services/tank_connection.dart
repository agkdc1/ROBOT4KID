import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/command.dart';

/// Manages WebSocket connection to ESP32 hull node.
class TankConnection {
  WebSocketChannel? _channel;
  bool _connected = false;
  Timer? _heartbeatTimer;
  Timer? _commandTimer;

  final String hullIp;
  final int port;
  final void Function(bool connected)? onConnectionChanged;
  final void Function(Uint8List data)? onDataReceived;

  TankConnection({
    this.hullIp = '192.168.4.1',
    this.port = 80,
    this.onConnectionChanged,
    this.onDataReceived,
  });

  bool get isConnected => _connected;

  Future<void> connect() async {
    try {
      final uri = Uri.parse('ws://$hullIp:$port/ws');
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;
      _connected = true;
      onConnectionChanged?.call(true);

      _channel!.stream.listen(
        (data) {
          if (data is List<int>) {
            onDataReceived?.call(Uint8List.fromList(data));
          }
        },
        onDone: () {
          _connected = false;
          onConnectionChanged?.call(false);
        },
        onError: (_) {
          _connected = false;
          onConnectionChanged?.call(false);
        },
      );

      // Start heartbeat
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _sendHeartbeat(),
      );
    } catch (e) {
      _connected = false;
      onConnectionChanged?.call(false);
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _commandTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    onConnectionChanged?.call(false);
  }

  void sendCommand(TankCommand command) {
    if (_connected && _channel != null) {
      _channel!.sink.add(command.toBytes());
    }
  }

  void _sendHeartbeat() {
    if (_connected) {
      sendCommand(TankCommand(type: 0x06)); // CMD_HEARTBEAT
    }
  }

  /// Start sending move commands at a fixed rate (20Hz).
  void startCommandStream(TankCommand Function() commandBuilder) {
    _commandTimer?.cancel();
    _commandTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => sendCommand(commandBuilder()),
    );
  }

  void stopCommandStream() {
    _commandTimer?.cancel();
  }
}
