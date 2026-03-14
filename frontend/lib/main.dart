import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/tank_state.dart';
import 'models/train_state.dart';
import 'models/fcs_state.dart';
import 'models/app_config.dart';
import 'screens/project_screen.dart';
import 'screens/control_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape orientation for tablet
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide system UI for immersive control experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load persisted config
  final appConfig = AppConfig();
  await appConfig.load();

  runApp(NL2BotApp(appConfig: appConfig));
}

class NL2BotApp extends StatelessWidget {
  final AppConfig appConfig;

  const NL2BotApp({super.key, required this.appConfig});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TankState()),
        ChangeNotifierProvider(create: (_) => TrainState()),
        ChangeNotifierProvider(create: (_) => FcsState()),
        ChangeNotifierProvider.value(value: appConfig),
      ],
      child: MaterialApp(
        title: 'NL2Bot Controller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        // Skip project selection if default project is set
        initialRoute: appConfig.skipProjectSelection &&
                appConfig.defaultProjectId != null
            ? '/control'
            : '/projects',
        routes: {
          '/projects': (context) => const ProjectScreen(),
          '/control': (context) => const ControlScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
