import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model for a single button.
class ButtonConfig {
  String name;
  String image;
  String command;
  List<List<String>> hotkeys;
  bool withError;

  ButtonConfig({
    this.name = '',
    this.image = '',
    this.command = '',
    List<List<String>>? hotkeys,
    this.withError = false,
  }) : hotkeys = hotkeys ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'image': image,
        'command': command,
        'hotkeys': hotkeys,
        'with_error': withError,
      };

  factory ButtonConfig.fromJson(Map<String, dynamic> json) => ButtonConfig(
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
        command: json['command'] as String? ?? '',
        hotkeys: (json['hotkeys'] as List<dynamic>?)
                ?.map((e) =>
                    (e as List<dynamic>).map((k) => k.toString()).toList())
                .toList() ??
            [],
        withError: json['with_error'] as bool? ?? false,
      );
}

/// Model for a profile (group of buttons).
class Profile {
  String name;
  Map<String, ButtonConfig> buttons;

  Profile({this.name = '', Map<String, ButtonConfig>? buttons})
      : buttons = buttons ?? {};

  Map<String, dynamic> toJson() => {
        'name': name,
        'buttons':
            buttons.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String? ?? '',
        buttons: (json['buttons'] as Map<String, dynamic>?)
                ?.map((k, v) =>
                    MapEntry(k, ButtonConfig.fromJson(v as Map<String, dynamic>))) ??
            {},
      );
}

/// Model for Spotify settings.
class SpotifySettings {
  String clientId;
  String clientSecret;
  bool enabled;

  SpotifySettings({
    this.clientId = '',
    this.clientSecret = '',
    this.enabled = false,
  });

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'client_secret': clientSecret,
        'enabled': enabled,
      };

  factory SpotifySettings.fromJson(Map<String, dynamic> json) =>
      SpotifySettings(
        clientId: json['client_id'] as String? ?? '',
        clientSecret: json['client_secret'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
      );
}

/// Full app configuration.
class AppConfig {
  final DaemonSettings daemon;
  SpotifySettings spotify;
  List<Profile> profiles;

  AppConfig({
    DaemonSettings? daemon,
    SpotifySettings? spotify,
    List<Profile>? profiles,
  })  : daemon = daemon ?? DaemonSettings(),
        spotify = spotify ?? SpotifySettings(),
        profiles = profiles ?? [];

  Map<String, dynamic> toJson() => {
        'daemon': daemon.toJson(),
        'spotify': spotify.toJson(),
        'profiles': profiles.map((p) => p.toJson()).toList(),
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        daemon: DaemonSettings.fromJson(json['daemon'] ?? {}),
        spotify: SpotifySettings.fromJson(json['spotify'] ?? {}),
        profiles: (json['profiles'] as List<dynamic>?)
                ?.map((e) => Profile.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class DaemonSettings {
  String host;
  int port;

  DaemonSettings({this.host = '0.0.0.0', this.port = 42069});

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
      };

  factory DaemonSettings.fromJson(Map<String, dynamic> json) => DaemonSettings(
        host: json['host'] as String? ?? '0.0.0.0',
        port: json['port'] as int? ?? 42069,
      );
}

/// Service to communicate with the daemon API.
class DaemonApiService extends ChangeNotifier {
  String _baseUrl = 'http://localhost:42069';
  bool _connected = false;

  String get baseUrl => _baseUrl;
  bool get connected => _connected;

  Future<bool> connect({String host = 'localhost', int port = 42069}) async {
    _baseUrl = 'http://$host:$port';
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _connected = true;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[API] Connection failed: $e');
    }
    _connected = false;
    notifyListeners();
    return false;
  }

  Future<AppConfig?> fetchConfig() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/config'));
      if (response.statusCode == 200) {
        return AppConfig.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[API] Config fetch failed: $e');
    }
    return null;
  }

  Future<bool> saveConfig(AppConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/config/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] Config save failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> startSpotifyAuth() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/spotify/auth'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[API] Spotify auth start failed: $e');
    }
    return null;
  }

  void disconnect() {
    _connected = false;
    notifyListeners();
  }
}
