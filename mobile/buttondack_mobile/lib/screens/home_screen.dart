import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/daemon_service.dart';
import '../widgets/button_tile.dart';
import '../widgets/profile_switcher.dart';
import '../widgets/spotify_card.dart';

/// Main home screen with button grid and Spotify overlay.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _hostController =
      TextEditingController();
  final TextEditingController _portController =
      TextEditingController();
  bool _showConnectDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load saved connection and connect
      final daemon = context.read<DaemonService>();
      final saved = await daemon.loadSavedConnection();
      _hostController.text = saved['host'] as String;
      _portController.text = '${saved['port']}';
      daemon.connect(
        host: saved['host'] as String,
        port: saved['port'] as int,
      );
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaemonService>(
      builder: (context, daemon, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF1a1a2e),
          appBar: AppBar(
            backgroundColor: const Color(0xFF16213e),
            title: const Text(
              'ButtonDack',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _showConnectionDialog(context, daemon),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: daemon.connected
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: daemon.connected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          daemon.connected ? 'Verbunden' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: daemon.connected
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Spotify Now Playing
                if (daemon.config?.spotify.enabled == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: SpotifyCard(
                      track: daemon.currentTrack,
                      enabled: true,
                    ),
                  ),

                // Profile switcher
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: ProfileSwitcher(
                    profiles: daemon.profiles,
                    activeProfile: daemon.activeProfile,
                    onChanged: (name) =>
                        daemon.setActiveProfile(name),
                  ),
                ),

                // Button grid or connect prompt
                Expanded(
                  child: daemon.currentProfile != null
                      ? _buildButtonGrid(context, daemon)
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off,
                                  size: 64,
                                  color: Colors.grey.shade600),
                              const SizedBox(height: 16),
                              Text(
                                'Nicht verbunden',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () =>
                                    _showConnectionDialog(
                                        context, daemon),
                                icon: const Icon(Icons.wifi_find),
                                label: const Text('Verbinden'),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonGrid(
      BuildContext context, DaemonService daemon) {
    final profile = daemon.currentProfile!;
    final buttons = profile.buttons.entries.toList();

    final crossAxisCount = buttons.length <= 4
        ? 2
        : buttons.length <= 9
            ? 3
            : 4;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: buttons.length,
      itemBuilder: (context, index) {
        final entry = buttons[index];
        return ButtonTile(
          buttonId: entry.key,
          button: entry.value,
          daemon: daemon,
          profileName: profile.name,
        );
      },
    );
  }

  void _showConnectionDialog(
      BuildContext context, DaemonService daemon) {
    // Ensure controllers have current values
    _hostController.text = daemon.host.isNotEmpty
        ? daemon.host
        : _hostController.text;
    _portController.text = daemon.port != 0
        ? '${daemon.port}'
        : (_portController.text.isEmpty ? '42069' : _portController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: const Text('Verbindung',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: '192.168.1.100',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '42069',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${daemon.connected ? "Verbunden" : "Getrennt"}',
              style: TextStyle(
                color: daemon.connected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final host = _hostController.text.trim();
              final port = int.tryParse(
                      _portController.text.trim()) ??
                  42069;
              daemon.connect(host: host, port: port);
              Navigator.pop(ctx);
            },
            child: const Text('Verbinden'),
          ),
        ],
      ),
    );
  }
}
