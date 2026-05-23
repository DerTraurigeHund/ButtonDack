import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/config_model.dart';
import 'screens/profiles_screen.dart';
import 'screens/spotify_settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => DaemonApiService(),
      child: const ButtonDackSettingsApp(),
    ),
  );
}

class ButtonDackSettingsApp extends StatelessWidget {
  const ButtonDackSettingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ButtonDack Settings',
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
      home: const SettingsHomeScreen(),
    );
  }
}

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({super.key});

  @override
  State<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends State<SettingsHomeScreen> {
  AppConfig? _config;
  bool _loading = true;
  int _selectedIndex = 0;
  final TextEditingController _hostCtrl = TextEditingController(text: 'localhost');
  final TextEditingController _portCtrl = TextEditingController(text: '42069');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _connect() async {
    final api = context.read<DaemonApiService>();
    setState(() => _loading = true);

    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 42069;

    final connected = await api.connect(host: host, port: port);
    if (connected) {
      final config = await api.fetchConfig();
      setState(() {
        _config = config;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<DaemonApiService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ButtonDack Settings'),
        actions: [
          // Connection status
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(
                Icons.circle,
                size: 10,
                color: api.connected ? Colors.green : Colors.red,
              ),
              label: Text(api.connected ? 'Connected' : 'Offline'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !api.connected
              ? _buildConnectScreen(api)
              : _config == null
                  ? const Center(child: Text('Failed to load config'))
                  : _buildMainScreen(api),
      bottomNavigationBar: api.connected && _config != null
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard),
                  label: 'Profiles',
                ),
                NavigationDestination(
                  icon: Icon(Icons.music_note),
                  label: 'Spotify',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Daemon',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildConnectScreen(DaemonApiService api) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Connect to ButtonDack Daemon',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Daemon Host',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScreen(DaemonApiService api) {
    switch (_selectedIndex) {
      case 0:
        return ProfilesScreen(
          config: _config!,
          onChanged: (cfg) {
            setState(() => _config = cfg);
            api.saveConfig(cfg);
          },
        );
      case 1:
        return SpotifySettingsScreen(
          config: _config!,
          onChanged: (cfg) {
            setState(() => _config = cfg);
            api.saveConfig(cfg);
          },
          api: api,
        );
      case 2:
        return _buildDaemonScreen(api);
      default:
        return const SizedBox();
    }
  }

  Widget _buildDaemonScreen(DaemonApiService api) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daemon Info',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _infoRow('Status', api.connected ? 'Running' : 'Stopped'),
                _infoRow('Address', api.baseUrl),
                _infoRow('Version', '1.0.0-dev'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    api.disconnect();
                    setState(() => _config = null);
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
