import 'dart:async';
import 'package:flutter/material.dart';
import '../models/config_model.dart';
import '../services/daemon_engine.dart';

/// Screen for Spotify integration setup.
class SpotifySettingsScreen extends StatefulWidget {
  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;
  final DaemonEngine engine;

  const SpotifySettingsScreen({
    super.key,
    required this.config,
    required this.onChanged,
    required this.engine,
  });

  @override
  State<SpotifySettingsScreen> createState() => _SpotifySettingsScreenState();
}

class _SpotifySettingsScreenState extends State<SpotifySettingsScreen> {
  late TextEditingController _clientIdCtrl;
  late TextEditingController _clientSecretCtrl;

  @override
  void initState() {
    super.initState();
    _clientIdCtrl =
        TextEditingController(text: widget.config.spotify.clientId);
    _clientSecretCtrl =
        TextEditingController(text: widget.config.spotify.clientSecret);

    // Listen for engine auth state changes
    widget.engine.addListener(_onEngineChanged);
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final spotify = widget.config.spotify;
    final engine = widget.engine;

    return Scaffold(
      appBar: AppBar(title: const Text('Spotify Integration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: spotify.enabled && engine.spotifyAuthenticated
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: spotify.enabled && engine.spotifyAuthenticated
                          ? Colors.green
                          : Colors.grey,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Spotify',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          engine.spotifyAuthenticated
                              ? 'Authenticated'
                              : spotify.enabled
                                  ? 'Configured'
                                  : 'Not configured',
                          style: TextStyle(
                            color: engine.spotifyAuthenticated
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: spotify.enabled,
                    onChanged: (v) {
                      spotify.enabled = v;
                      widget.onChanged(widget.config);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Now playing preview
          if (engine.currentTrack != null &&
              !engine.currentTrack!.isEmpty) ...[
            const SizedBox(height: 8),
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
                title: Text(engine.currentTrack!.trackName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(engine.currentTrack!.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // API credentials
          Text('API Credentials',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _clientIdCtrl,
            decoration: const InputDecoration(
              labelText: 'Client ID',
              border: OutlineInputBorder(),
              helperText: 'From Spotify Developer Dashboard',
            ),
            onChanged: (v) {
              spotify.clientId = v;
              widget.onChanged(widget.config);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientSecretCtrl,
            decoration: const InputDecoration(
              labelText: 'Client Secret',
              border: OutlineInputBorder(),
              helperText: 'From Spotify Developer Dashboard',
            ),
            obscureText: true,
            onChanged: (v) {
              spotify.clientSecret = v;
              widget.onChanged(widget.config);
            },
          ),

          const SizedBox(height: 24),

          // Auth section
          Text('Authentication',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Use Device Code flow to authorize your Spotify account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          if (engine.spotifyAuthInProgress) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            if (engine.spotifyAuthUrl.isNotEmpty)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Open ${engine.spotifyAuthUrl}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          engine.spotifyUserCode,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Enter this code on the Spotify website'),
                    ],
                  ),
                ),
              ),
          ],

          FilledButton.icon(
            onPressed: (engine.spotifyAuthInProgress ||
                    spotify.clientId.isEmpty)
                ? null
                : _startAuth,
            icon: const Icon(Icons.link),
            label: const Text('Authorize with Spotify'),
          ),

          const SizedBox(height: 32),

          // How to get credentials
          Text('How to get credentials',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '1. Go to https://developer.spotify.com/dashboard\n'
            '2. Create an app\n'
            '3. Copy Client ID and Client Secret\n'
            '4. Enter them above and click Authorize\n'
            '5. The daemon handles Device Code auth automatically',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _startAuth() {
    // The engine handles the entire auth flow internally
    // It will update state and notify listeners
    widget.engine.startSpotifyAuth();
  }
}
