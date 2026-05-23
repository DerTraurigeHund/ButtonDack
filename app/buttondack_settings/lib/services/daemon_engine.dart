import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/config_model.dart';
import 'config_service.dart';
import 'action_runner.dart';

/// Message format for WebSocket communication.
class WsMessage {
  final String type;
  final dynamic payload;

  WsMessage({required this.type, this.payload});

  String toJson() => jsonEncode({
        'type': type,
        if (payload != null) 'payload': payload,
      });

  factory WsMessage.fromJson(Map<String, dynamic> json) => WsMessage(
        type: json['type'] as String? ?? '',
        payload: json['payload'],
      );
}

/// TrackInfo for the currently playing Spotify track.
class TrackInfo {
  final bool isPlaying;
  final String trackName;
  final String artist;
  final String albumName;
  final String albumArtUrl;
  final int progressMs;
  final int durationMs;
  final String trackUrl;

  TrackInfo({
    this.isPlaying = false,
    this.trackName = '',
    this.artist = '',
    this.albumName = '',
    this.albumArtUrl = '',
    this.progressMs = 0,
    this.durationMs = 0,
    this.trackUrl = '',
  });

  Map<String, dynamic> toJson() => {
        'is_playing': isPlaying,
        'track_name': trackName,
        'artist': artist,
        'album_name': albumName,
        'album_art_url': albumArtUrl,
        'progress_ms': progressMs,
        'duration_ms': durationMs,
        'track_url': trackUrl,
      };

  bool get isEmpty => trackName.isEmpty;
}

/// Internal Spotify token storage.
class _SpotifyToken {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiry;

  _SpotifyToken({
    required this.accessToken,
    this.refreshToken,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Main daemon engine — runs WebSocket server, Spotify polling, action dispatch.
class DaemonEngine extends ChangeNotifier {
  final ConfigService configService;
  final ActionRunner actionRunner;

  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  bool _running = false;

  // Spotify
  _SpotifyToken? _spotifyToken;
  Timer? _spotifyPollTimer;
  TrackInfo? _currentTrack;
  bool _spotifyAuthInProgress = false;
  String _spotifyAuthUrl = '';
  String _spotifyUserCode = '';

  // Callbacks for UI
  void Function(TrackInfo track)? onTrackChanged;

  DaemonEngine({
    required this.configService,
    ActionRunner? actionRunner,
  }) : actionRunner = actionRunner ?? ActionRunner();

  bool get running => _running;
  int get clientCount => _clients.length;
  TrackInfo? get currentTrack => _currentTrack;
  bool get spotifyEnabled => configService.config.spotify.enabled;
  bool get spotifyAuthenticated => _spotifyToken != null;
  bool get spotifyAuthInProgress => _spotifyAuthInProgress;
  String get spotifyAuthUrl => _spotifyAuthUrl;
  String get spotifyUserCode => _spotifyUserCode;

  int get port => configService.config.daemon.port;
  String get host => configService.config.daemon.host;

  /// Start the Spotify device auth flow (public wrapper).
  void startSpotifyAuth() {
    _startSpotifyAuth();
  }

  /// Start the WebSocket server.
  Future<bool> start() async {
    if (_running) return true;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        configService.config.daemon.port,
      );

      _running = true;
      debugPrint('[Daemon] Server listening on :${configService.config.daemon.port}');

      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('[Daemon] Server error: $e');
      });

      // Start Spotify polling if configured
      if (spotifyEnabled) {
        _startSpotifyPolling();
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Daemon] Failed to start: $e');
      _running = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop the server.
  Future<void> stop() async {
    _stopSpotifyPolling();

    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();

    await _server?.close(force: true);
    _server = null;
    _running = false;

    debugPrint('[Daemon] Server stopped');
    notifyListeners();
  }

  /// Restart the server.
  Future<bool> restart() async {
    await stop();
    return start();
  }

  void _handleRequest(HttpRequest request) {
    if (request.uri.path == '/ws' && request.method == 'GET') {
      WebSocketTransformer.upgrade(request).then((ws) {
        _handleWebSocket(ws);
      }).catchError((e) {
        debugPrint('[Daemon] WS upgrade failed: $e');
      });
      return;
    }

    // REST API
    _handleRestApi(request);
  }

  // ── WebSocket ──

  void _handleWebSocket(WebSocket ws) {
    _clients.add(ws);
    debugPrint('[Daemon] WS client connected (${_clients.length} total)');

    // Send initial config
    ws.add(WsMessage(
      type: 'config',
      payload: configService.config.toJson(),
    ).toJson());

    // Send current track if available
    if (_currentTrack != null && !_currentTrack!.isEmpty) {
      ws.add(WsMessage(
        type: 'spotify_track',
        payload: _currentTrack!.toJson(),
      ).toJson());
    }

    ws.listen(
      (data) {
        try {
          final msg = WsMessage.fromJson(
              jsonDecode(data as String) as Map<String, dynamic>);
          _handleWsMessage(ws, msg);
        } catch (e) {
          debugPrint('[Daemon] WS message error: $e');
        }
      },
      onDone: () {
        _clients.remove(ws);
        debugPrint('[Daemon] WS client disconnected (${_clients.length} left)');
      },
      onError: (e) {
        _clients.remove(ws);
        debugPrint('[Daemon] WS error: $e');
      },
    );
  }

  void _handleWsMessage(WebSocket ws, WsMessage msg) {
    switch (msg.type) {
      case 'action':
        _handleAction(ws, msg.payload as Map<String, dynamic>);
        break;
      case 'ping':
        ws.add(WsMessage(type: 'pong').toJson());
        break;
    }
  }

  Future<void> _handleAction(WebSocket ws, Map<String, dynamic> payload) async {
    final profileName = payload['profile'] as String? ?? '';
    final buttonId = payload['button_id'] as String? ?? '';

    // Find button in config
    ButtonConfig? button;
    for (final p in configService.config.profiles) {
      if (p.name == profileName) {
        button = p.buttons[buttonId];
        break;
      }
    }

    if (button == null) {
      ws.add(WsMessage(
        type: 'action_result',
        payload: {
          'success': false,
          'error': 'Button $profileName/$buttonId not found',
        },
      ).toJson());
      return;
    }

    final result = await actionRunner.executeButton(
      command: button.command,
      hotkeys: button.hotkeys,
      withError: button.withError,
    );

    ws.add(WsMessage(type: 'action_result', payload: result.toJson()).toJson());
  }

  /// Broadcast a message to all connected WebSocket clients.
  void _broadcast(WsMessage msg) {
    final data = msg.toJson();
    for (final client in _clients.toList()) {
      try {
        client.add(data);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  // ── REST API ──

  void _handleRestApi(HttpRequest request) {
    try {
      final uri = request.uri;
      final path = uri.path;

      if (path == '/api/health' && request.method == 'GET') {
        _jsonResponse(request, {
          'status': 'ok',
          'version': '1.0.0-dev',
          'clients': _clients.length,
          'uptime': 'since startup',
        });
        return;
      }

      if (path == '/api/config' && request.method == 'GET') {
        _jsonResponse(request, configService.config.toJson());
        return;
      }

      if (path == '/api/config/update' && request.method == 'POST') {
        _readBody(request).then((body) async {
          final data = jsonDecode(body);
          await configService
              .update(AppConfig.fromJson(data as Map<String, dynamic>));
          _jsonResponse(request, {'status': 'saved'});
        });
        return;
      }

      if (path == '/api/action' && request.method == 'POST') {
        _readBody(request).then((body) async {
          final data = jsonDecode(body) as Map<String, dynamic>;
          final profileName = data['profile'] as String? ?? '';
          final buttonId = data['button_id'] as String? ?? '';

          ButtonConfig? button;
          for (final p in configService.config.profiles) {
            if (p.name == profileName) {
              button = p.buttons[buttonId];
              break;
            }
          }

          if (button == null) {
            _jsonResponse(request, {'success': false, 'error': 'Button not found'},
                status: 404);
            return;
          }

          final result = await actionRunner.executeButton(
            command: button.command,
            hotkeys: button.hotkeys,
            withError: button.withError,
          );
          _jsonResponse(request, result.toJson());
        });
        return;
      }

      if (path == '/api/spotify/auth' && request.method == 'POST') {
        _startSpotifyAuth();
        _jsonResponse(request, {
          'user_code': _spotifyUserCode,
          'verification_url': _spotifyAuthUrl,
        });
        return;
      }

      if (path == '/api/spotify/poll' && request.method == 'GET') {
        _jsonResponse(request, _currentTrack?.toJson() ?? {});
        return;
      }

      if (path == '/api/spotify/status' && request.method == 'GET') {
        _jsonResponse(request, {
          'enabled': spotifyEnabled,
          'authenticated': spotifyAuthenticated,
        });
        return;
      }

      // 404
      _jsonResponse(request, {'error': 'not found'}, status: 404);
    } catch (e) {
      debugPrint('[Daemon] REST handler error: $e');
      _jsonResponse(request, {'error': 'internal error'}, status: 500);
    }
  }

  void _jsonResponse(HttpRequest request, dynamic data,
      {int status = 200}) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  // ── Spotify ──

  Future<void> _startSpotifyAuth() async {
    _spotifyAuthInProgress = true;
    notifyListeners();

    try {
      final clientId = configService.config.spotify.clientId;
      if (clientId.isEmpty) {
        debugPrint('[Spotify] No client ID configured');
        _spotifyAuthInProgress = false;
        notifyListeners();
        return;
      }

      // Step 1: Request device code
      final deviceResp = await http.post(
        Uri.parse('https://accounts.spotify.com/api/device'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'client_id=$clientId&scope=user-read-playback-state%20user-read-currently-playing',
      );

      if (deviceResp.statusCode != 200) {
        debugPrint('[Spotify] Device code request failed: ${deviceResp.body}');
        _spotifyAuthInProgress = false;
        notifyListeners();
        return;
      }

      final deviceData = jsonDecode(deviceResp.body) as Map<String, dynamic>;
      _spotifyUserCode = deviceData['user_code'] as String;
      _spotifyAuthUrl = deviceData['verification_uri'] as String;
      final deviceCode = deviceData['device_code'] as String;
      final interval = deviceData['interval'] as int? ?? 5;

      notifyListeners();

      // Step 2: Poll for token
      _pollDeviceAuth(clientId, deviceCode, interval);
    } catch (e) {
      debugPrint('[Spotify] Auth error: $e');
      _spotifyAuthInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _pollDeviceAuth(
      String clientId, String deviceCode, int interval) async {
    final timeout = Duration(minutes: 5);
    final start = DateTime.now();

    while (DateTime.now().difference(start) < timeout) {
      await Future.delayed(Duration(seconds: interval));

      try {
        final resp = await http.post(
          Uri.parse('https://accounts.spotify.com/api/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'grant_type=urn:ietf:params:oauth:grant-type:device_code'
              '&device_code=$deviceCode'
              '&client_id=$clientId',
        );

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          _spotifyToken = _SpotifyToken(
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String?,
            expiry: DateTime.now()
                .add(Duration(seconds: data['expires_in'] as int? ?? 3600)),
          );

          _spotifyAuthInProgress = false;

          // Enable Spotify
          configService.config.spotify.enabled = true;
          await configService.save();

          // Start polling
          _startSpotifyPolling();
          notifyListeners();
          return;
        }

        final errData = jsonDecode(resp.body) as Map<String, dynamic>;
        final err = errData['error'] as String?;

        if (err == 'authorization_pending') continue;
        if (err == 'access_denied') {
          debugPrint('[Spotify] Auth denied by user');
          _spotifyAuthInProgress = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('[Spotify] Poll error: $e');
        continue;
      }
    }

    _spotifyAuthInProgress = false;
    notifyListeners();
    debugPrint('[Spotify] Auth timed out');
  }

  Future<void> _refreshSpotifyToken() async {
    if (_spotifyToken?.refreshToken == null) return;

    try {
      final resp = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token'
            '&refresh_token=${_spotifyToken!.refreshToken}'
            '&client_id=${configService.config.spotify.clientId}'
            '&client_secret=${configService.config.spotify.clientSecret}',
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _spotifyToken = _SpotifyToken(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String? ?? _spotifyToken?.refreshToken,
          expiry: DateTime.now()
              .add(Duration(seconds: data['expires_in'] as int? ?? 3600)),
        );
      }
    } catch (e) {
      debugPrint('[Spotify] Token refresh failed: $e');
    }
  }

  void _startSpotifyPolling() {
    _stopSpotifyPolling();

    if (!spotifyEnabled) return;

    _spotifyPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _pollSpotify();
    });
  }

  void _stopSpotifyPolling() {
    _spotifyPollTimer?.cancel();
    _spotifyPollTimer = null;
  }

  Future<void> _pollSpotify() async {
    if (!spotifyEnabled || _spotifyToken == null) return;

    if (_spotifyToken!.isExpired) {
      await _refreshSpotifyToken();
    }

    if (_spotifyToken == null) return;

    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player/currently-playing'),
        headers: {'Authorization': 'Bearer ${_spotifyToken!.accessToken}'},
      );

      if (resp.statusCode == 204) {
        // Nothing playing
        if (_currentTrack != null && !_currentTrack!.isEmpty) {
          _currentTrack = TrackInfo();
          _broadcastTrack();
        }
        return;
      }

      if (resp.statusCode == 401) {
        await _refreshSpotifyToken();
        return;
      }

      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final item = data['item'] as Map<String, dynamic>?;

      if (item == null) {
        _currentTrack = TrackInfo();
        _broadcastTrack();
        return;
      }

      // Extract album art URL
      String albumArtUrl = '';
      final album = item['album'] as Map<String, dynamic>?;
      if (album != null) {
        final images = album['images'] as List<dynamic>? ?? [];
        if (images.isNotEmpty) {
          // Pick medium image
          albumArtUrl = images.isNotEmpty
              ? (images.length > 1
                  ? (images[1]['url'] as String)
                  : (images[0]['url'] as String))
              : '';
        }
      }

      // Extract artists
      final artists = (item['artists'] as List<dynamic>?)
              ?.map((a) => (a as Map<String, dynamic>)['name'] as String)
              .join(', ') ??
          '';

      final track = TrackInfo(
        isPlaying: data['is_playing'] as bool? ?? false,
        trackName: item['name'] as String? ?? '',
        artist: artists,
        albumName: album?['name'] as String? ?? '',
        albumArtUrl: albumArtUrl,
        progressMs: data['progress_ms'] as int? ?? 0,
        durationMs: item['duration_ms'] as int? ?? 0,
        trackUrl: item['external_urls'] is Map
            ? ((item['external_urls'] as Map)['spotify'] as String? ?? '')
            : '',
      );

      // Only broadcast if changed
      final oldName = _currentTrack?.trackName ?? '';
      final oldPlaying = _currentTrack?.isPlaying ?? false;

      if (track.trackName != oldName || track.isPlaying != oldPlaying) {
        _currentTrack = track;
        _broadcastTrack();
      }
    } catch (e) {
      debugPrint('[Spotify] Poll error: $e');
    }
  }

  void _broadcastTrack() {
    if (_currentTrack == null) return;
    _broadcast(WsMessage(
      type: 'spotify_track',
      payload: _currentTrack!.toJson(),
    ));
    onTrackChanged?.call(_currentTrack!);
    notifyListeners();
  }

  /// Read the full request body as a String.
  Future<String> _readBody(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(
        [], (prev, chunk) => prev..addAll(chunk));
    return utf8.decode(bytes);
  }

  @override
  void dispose() {
    _stopSpotifyPolling();
    for (final client in _clients) {
      client.close();
    }
    _server?.close(force: true);
    super.dispose();
  }
}
