import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/config_service.dart';
import 'services/daemon_engine.dart';
import 'services/action_runner.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService()),
        ChangeNotifierProvider(create: (_) => ActionRunner()),
        ChangeNotifierProxyProvider2<ConfigService, ActionRunner, DaemonEngine>(
          create: (ctx) => DaemonEngine(
            configService: ctx.read<ConfigService>(),
            actionRunner: ctx.read<ActionRunner>(),
          ),
          update: (ctx, cfg, runner, previous) => previous!,
        ),
      ],
      child: const ButtonDackApp(),
    ),
  );
}

class ButtonDackApp extends StatelessWidget {
  const ButtonDackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ButtonDack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6B4EFF),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6B4EFF),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
