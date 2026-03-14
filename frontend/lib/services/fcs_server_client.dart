import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fcs_state.dart';

/// Client for communicating FCS shot data to the planning server
/// and receiving updated trajectory coefficients.
class FcsServerClient {
  final String serverUrl;

  FcsServerClient({required this.serverUrl});

  /// Upload shot records for RL training.
  Future<void> uploadShotData(List<ShotRecord> shots) async {
    if (shots.isEmpty) return;

    final body = jsonEncode({
      'shots': shots.map((s) => s.toJson()).toList(),
    });

    await http.post(
      Uri.parse('$serverUrl/api/v1/fcs/shots'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  /// Fetch latest trajectory coefficients from server.
  Future<TrajectoryCoefficients?> fetchCoefficients() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/v1/fcs/coefficients'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TrajectoryCoefficients.fromJson(json);
      }
    } catch (_) {
      // Server not available — use local coefficients
    }
    return null;
  }

  /// Request server to run RL training on accumulated shot data.
  Future<TrajectoryCoefficients?> requestTraining() async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/v1/fcs/train'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TrajectoryCoefficients.fromJson(json['coefficients']);
      }
    } catch (_) {}
    return null;
  }
}
