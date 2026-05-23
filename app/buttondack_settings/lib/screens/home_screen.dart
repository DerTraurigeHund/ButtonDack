import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/daemon_engine.dart';
import '../services/action_runner.dart';
import 'profiles_screen.dart';
import 'spotify_settings_screen.dart';

/// Main screen combining daemon status with settings navigation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final cfg = context.read<ConfigService>();
    await cfg.load();

    // Auto-start daemon
    final engine = context.read<DaemonEngine>();
    await engine.start();

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<DaemonEngine>();
    final cfg = context.watch<ConfigService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ButtonDack'),
        centerTitle: false,
        actions: [
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _DaemonStatusChip(engine: engine),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting ButtonDack...'),
                ],
              ),
            )
          : _buildBody(engine, cfg),
      bottomNavigationBar: NavigationBar(
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
      ),
    );
  }

  Widget _buildBody(DaemonEngine engine, ConfigService cfg) {
    switch (_selectedIndex) {
      case 0:
        return ProfilesScreen(
          config: cfg.config,
          onChanged: (updatedConfig) {
            cfg.update(updatedConfig);
          },
        );
      case 1:
        return SpotifySettingsScreen(
          config: cfg.config,
          onChanged: (updatedConfig) {
            cfg.update(updatedConfig);
            // Restart daemon if Spotify settings changed
            engine.restart();
          },
          engine: engine,
        );
      case 2:
        return _DaemonSettingsTab(engine: engine, cfg: cfg);
      default:
        return const SizedBox();
    }
  }
}

/// Daemon status badge in the app bar.
class _DaemonStatusChip extends StatelessWidget {
  final DaemonEngine engine;
  const _DaemonStatusChip({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: engine.running
            ? Colors.green.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: engine.running
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: engine.running ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            engine.running
                ? 'Port ${engine.port}'
                : 'Stopped',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: engine.running ? Colors.green : Colors.red.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

/// Daemon control tab.
class _DaemonSettingsTab extends StatelessWidget {
  final DaemonEngine engine;
  final ConfigService cfg;

  const _DaemonSettingsTab({
    required this.engine,
    required this.cfg,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud,
                      color: engine.running ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            engine.running ? 'Daemon Running' : 'Daemon Stopped',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            engine.running
                                ? '${engine.clientCount} client${engine.clientCount == 1 ? '' : 's'} connected'
                                : 'The WebSocket server is not running',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: engine.running,
                      onChanged: (v) {
                        if (v) {
                          engine.start();
                        } else {
                          engine.stop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Spotify now playing
        if (engine.currentTrack != null && !engine.currentTrack!.isEmpty)
          Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: engine.currentTrack!.albumArtUrl.isNotEmpty
                    ? Image.network(
                        engine.currentTrack!.albumArtUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.music_note),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.music_note),
                      ),
              ),
              title: Text(
                engine.currentTrack!.trackName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                engine.currentTrack!.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                engine.currentTrack!.isPlaying
                    ? Icons.play_circle_fill
                    : Icons.pause_circle_outline,
                color: const Color(0xFF1DB954),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Connection info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connection',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _infoRow('Status', engine.running ? 'Running' : 'Stopped', context),
                _infoRow('Host', engine.host, context),
                _infoRow('Port', '${engine.port}', context),
                _infoRow('Clients', '${engine.clientCount}', context),
                _infoRow(
                    'Spotify', cfg.config.spotify.enabled ? 'Enabled' : 'Disabled', context),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: engine.running
                            ? () => engine.restart()
                            : () => engine.start(),
                        icon: Icon(engine.running ? Icons.restart_alt : Icons.play_arrow),
                        label: Text(engine.running ? 'Restart' : 'Start'),
                      ),
                    ),
                    if (engine.running) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => engine.stop(),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Config info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configuration',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _infoRow('Profiles', '${cfg.config.profiles.length}', context),
                _infoRow(
                    'Total Buttons',
                    '${cfg.config.profiles.fold<int>(0, (sum, p) => sum + p.buttons.length)}', context),
                _infoRow('Config Path', cfg.configPath, context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7))),
          ),
        ],
      ),
    );
  }
}
