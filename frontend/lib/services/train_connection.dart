import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/command.dart';

/// Manages WebSocket connection to ESP32 train node.
class TrainConnection {
  WebSocketChannel? _channel;
  bool _connected = false;
  Timer? _heartbeatTimer;
  Timer? _commandTimer;

  final String trainIp;
  final int port;
  final void Function(bool connected)? onConnectionChanged;
  final void Function(Uint8List data)? onDataReceived;

  TrainConnection({
    this.trainIp = '192.168.4.1',
    this.port = 80,
    this.onConnectionChanged,
    this.onDataReceived,
  });

  bool get isConnected => _connected;

  Future<void> connect() async {
    try {
      final uri = Uri.parse('ws://$trainIp:$port/ws');
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

  void sendCommand(TrainCommand command) {
    if (_connected && _channel != null) {
      _channel!.sink.add(command.toBytes());
    }
  }

  void _sendHeartbeat() {
    if (_connected) {
      // Send a zero-speed drive command as heartbeat
      sendCommand(TrainCommand.drive(0));
    }
  }

  /// Start sending drive commands at a fixed rate (20Hz).
  void startCommandStream(TrainCommand Function() commandBuilder) {
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
