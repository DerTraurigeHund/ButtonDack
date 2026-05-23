import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// Manages the WebSocket connection to the ButtonDack daemon.
class DaemonService extends ChangeNotifier {
  WebSocketChannel? _channel;
  String _host = 'localhost';
  int _port = 42069;
  bool _connected = false;
  bool _reconnecting = false;
  Timer? _reconnectTimer;

  AppConfig? _config;
  TrackInfo? _currentTrack;
  String _activeProfile = '';

  // Getters
  bool get connected => _connected;
  AppConfig? get config => _config;
  TrackInfo? get currentTrack => _currentTrack;
  String get activeProfile => _activeProfile;
  String get connectionAddress => '$_host:$_port';

  List<Profile> get profiles => _config?.profiles ?? [];
  Profile? get currentProfile {
    if (_activeProfile.isEmpty && profiles.isNotEmpty) {
      _activeProfile = profiles.first.name;
    }
    try {
      return profiles.firstWhere((p) => p.name == _activeProfile);
    } catch (_) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
  }

  /// Connect to the daemon at the given address.
  Future<bool> connect({String host = 'localhost', int port = 42069}) async {
    _host = host;
    _port = port;

    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$_host:$_port/ws'),
      );

      await _channel!.ready;
      _connected = true;
      _reconnecting = false;
      notifyListeners();

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('[Daemon] WS error: $error');
          _connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[Daemon] WS disconnected');
          _connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );

      return true;
    } catch (e) {
      debugPrint('[Daemon] Connection failed: $e');
      _connected = false;
      notifyListeners();
      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect from the daemon.
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    notifyListeners();
  }

  /// Send a button press action.
  void sendAction(String profile, String buttonId) {
    if (!_connected) return;

    final message = jsonEncode({
      'type': 'action',
      'payload': {
        'profile': profile,
        'button_id': buttonId,
      },
    });
    _channel?.sink.add(message);
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      final payload = message['payload'];

      switch (type) {
        case 'config':
          _handleConfig(payload);
          break;
        case 'spotify_track':
          _handleSpotifyTrack(payload);
          break;
        case 'action_result':
          _handleActionResult(payload);
          break;
        case 'pong':
          break;
      }
    } catch (e) {
      debugPrint('[Daemon] Message parse error: $e');
    }
  }

  void _handleConfig(dynamic payload) {
    if (payload == null) return;
    try {
      _config = AppConfig.fromJson(payload as Map<String, dynamic>);
      notifyListeners();
    } catch (e) {
      debugPrint('[Daemon] Config parse error: $e');
    }
  }

  void _handleSpotifyTrack(dynamic payload) {
    if (payload == null) return;
    try {
      _currentTrack = TrackInfo.fromJson(payload as Map<String, dynamic>);
      notifyListeners();
    } catch (e) {
      debugPrint('[Daemon] Track parse error: $e');
    }
  }

  void _handleActionResult(dynamic payload) {
    debugPrint('[Daemon] Action result: $payload');
  }

  void _scheduleReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnecting = false;
      if (!_connected) {
        connect(host: _host, port: _port);
      }
    });
  }

  void setActiveProfile(String name) {
    _activeProfile = name;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
