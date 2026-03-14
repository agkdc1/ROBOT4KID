import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/tank_state.dart';
import 'screens/control_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force landscape orientation for tablet
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Hide system UI for immersive control experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const NL2BotApp());
}

class NL2BotApp extends StatelessWidget {
  const NL2BotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TankState(),
      child: MaterialApp(
        title: 'NL2Bot Controller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/control',
        routes: {
          '/control': (context) => const ControlScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
