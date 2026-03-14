import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// MJPEG stream viewer for ESP32-CAM feeds.
class MjpegView extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;

  const MjpegView({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Uint8List? _currentFrame;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _running = false;
  }

  Future<void> _startStream() async {
    _running = true;
    _error = null;

    try {
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        setState(() => _error = 'Stream error: ${response.statusCode}');
        return;
      }

      // Parse MJPEG multipart stream
      final boundary = _extractBoundary(response.headers['content-type'] ?? '');
      final buffer = <int>[];

      await for (final chunk in response.stream) {
        if (!_running) break;
        buffer.addAll(chunk);

        // Find JPEG frames delimited by boundary or SOI/EOI markers
        while (true) {
          final soiIndex = _findPattern(buffer, [0xFF, 0xD8]);
          final eoiIndex = _findPattern(buffer, [0xFF, 0xD9], soiIndex + 2);

          if (soiIndex < 0 || eoiIndex < 0) break;

          final frame = Uint8List.fromList(
            buffer.sublist(soiIndex, eoiIndex + 2),
          );

          if (mounted) {
            setState(() => _currentFrame = frame);
          }

          buffer.removeRange(0, eoiIndex + 2);
        }

        // Prevent buffer overflow
        if (buffer.length > 500000) {
          buffer.removeRange(0, buffer.length - 100000);
        }
      }
    } catch (e) {
      if (mounted && _running) {
        setState(() => _error = 'Connection failed');
        // Retry after delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && _running) _startStream();
      }
    }
  }

  int _findPattern(List<int> data, List<int> pattern, [int start = 0]) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  String _extractBoundary(String contentType) {
    final parts = contentType.split('boundary=');
    return parts.length > 1 ? parts[1].trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white24, size: 32),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.white24, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_currentFrame == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
        ),
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true, // Prevents flicker between frames
    );
  }
}

/// Camera view with main + PIP layout.
class CameraWithPip extends StatelessWidget {
  final String mainStreamUrl;
  final String pipStreamUrl;
  final bool swapped;
  final Widget? overlay;

  const CameraWithPip({
    super.key,
    required this.mainStreamUrl,
    required this.pipStreamUrl,
    this.swapped = false,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final mainUrl = swapped ? pipStreamUrl : mainStreamUrl;
    final pipUrl = swapped ? mainStreamUrl : pipStreamUrl;

    return Stack(
      children: [
        // Main camera — full screen
        Positioned.fill(
          child: MjpegView(streamUrl: mainUrl, fit: BoxFit.cover),
        ),

        // PIP camera — top left
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.5), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: MjpegView(streamUrl: pipUrl, fit: BoxFit.cover),
          ),
        ),

        // PIP label
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(
              swapped ? 'CHASSIS' : 'TURRET',
              style: const TextStyle(color: Colors.cyan, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // Overlay (crosshair, etc.)
        if (overlay != null) overlay!,
      ],
    );
  }
}
