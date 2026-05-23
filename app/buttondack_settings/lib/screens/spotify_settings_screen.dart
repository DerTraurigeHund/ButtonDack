import 'dart:async';
import 'package:flutter/material.dart';
import '../models/config_model.dart';

/// Screen for Spotify integration setup.
class SpotifySettingsScreen extends StatefulWidget {
  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;
  final DaemonApiService api;

  const SpotifySettingsScreen({
    super.key,
    required this.config,
    required this.onChanged,
    required this.api,
  });

  @override
  State<SpotifySettingsScreen> createState() => _SpotifySettingsScreenState();
}

class _SpotifySettingsScreenState extends State<SpotifySettingsScreen> {
  late TextEditingController _clientIdCtrl;
  late TextEditingController _clientSecretCtrl;

  bool _authInProgress = false;
  String _authStatus = '';

  @override
  void initState() {
    super.initState();
    _clientIdCtrl = TextEditingController(text: widget.config.spotify.clientId);
    _clientSecretCtrl =
        TextEditingController(text: widget.config.spotify.clientSecret);
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotify = widget.config.spotify;

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
                      color: spotify.enabled
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: spotify.enabled ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spotify',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          spotify.enabled ? 'Connected' : 'Not configured',
                          style: TextStyle(
                            color: spotify.enabled
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
                      setState(() {
                        spotify.enabled = v;
                      });
                      widget.onChanged(widget.config);
                    },
                  ),
                ],
              ),
            ),
          ),

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

          if (_authInProgress)
            Column(
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_authStatus, textAlign: TextAlign.center),
              ],
            ),

          FilledButton.icon(
            onPressed: _authInProgress ? null : _startAuth,
            icon: const Icon(Icons.link),
            label: const Text('Authorize Spotify'),
          ),

          if (_authStatus.contains('http')) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _authStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // How to get credentials
          Text('How to get credentials',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '1. Go to https://developer.spotify.com/dashboard\n'
            '2. Create an app\n'
            '3. Copy Client ID and Client Secret\n'
            '4. Add http://localhost:42069 to Redirect URIs\n'
            '5. Enter them above and click Authorize',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _startAuth() async {
    setState(() {
      _authInProgress = true;
      _authStatus = 'Requesting device code...';
    });

    final result = await widget.api.startSpotifyAuth();
    if (result != null) {
      setState(() {
        _authStatus =
            'Open ${result['verification_url']} and enter code: ${result['user_code']}';
      });
    } else {
      setState(() {
        _authInProgress = false;
        _authStatus = 'Failed to start authentication';
      });
    }
  }
}
