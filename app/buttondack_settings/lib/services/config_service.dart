import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/config_model.dart';

/// Handles loading and saving the app configuration on disk.
class ConfigService extends ChangeNotifier {
  AppConfig _config = AppConfig();
  String _configPath = '';
  bool _loaded = false;

  AppConfig get config => _config;
  bool get loaded => _loaded;
  String get configPath => _configPath;

  ConfigService() {
    _determinePath();
  }

  void _determinePath() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '.';
      _configPath = '$appData\\buttondack\\config.json';
    } else {
      final home = Platform.environment['HOME'] ?? '.';
      _configPath = '$home/.config/buttondack/config.json';
    }
  }

  /// Load config from disk. Creates defaults if missing.
  Future<AppConfig> load() async {
    final file = File(_configPath);
    if (await file.exists()) {
      try {
        final data = await file.readAsString();
        _config = AppConfig.fromJson(
            jsonDecode(data) as Map<String, dynamic>);
        _loaded = true;
        notifyListeners();
        return _config;
      } catch (e) {
        debugPrint('[Config] Parse error, using defaults: $e');
      }
    }

    // Create default config
    _config = _defaultConfig();
    _loaded = true;
    await save();
    notifyListeners();
    return _config;
  }

  /// Save config to disk.
  Future<void> save() async {
    final file = File(_configPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_config.toJson()));
    notifyListeners();
  }

  /// Update config in memory and persist.
  Future<void> update(AppConfig newConfig) async {
    _config = newConfig;
    await save();
  }

  /// Update specific fields.
  Future<void> updateSpotifySettings(SpotifySettings spotify) async {
    _config.spotify = spotify;
    await save();
  }

  Future<void> updateProfiles(List<Profile> profiles) async {
    _config.profiles = profiles;
    await save();
  }

  AppConfig _defaultConfig() {
    return AppConfig(
      daemon: DaemonSettings(host: '0.0.0.0', port: 42069),
      spotify: SpotifySettings(enabled: false),
      profiles: [
        Profile(name: 'System', buttons: {
          'btn0': ButtonConfig(
              name: 'Shutdown',
              image: 'shutdown.png',
              command: _isWindows() ? 'shutdown /s /t 0' : 'systemctl poweroff -i',
              withError: true),
          'btn1': ButtonConfig(
              name: 'Reboot',
              image: 'restart.png',
              command: _isWindows() ? 'shutdown /r /t 0' : 'systemctl reboot -i',
              withError: true),
          'btn2': ButtonConfig(
              name: 'Sleep',
              image: 'sleep.png',
              command: _isWindows() ? 'rundll32.exe powrprof.dll,SetSuspendState 0,1,0' : 'systemctl suspend -i',
              withError: true),
        }),
        Profile(name: 'Media', buttons: {
          'btn0': ButtonConfig(
              name: 'Play/Pause', image: 'play.png',
              command: _isWindows() ? '' : 'playerctl play-pause',
              hotkeys: [if (_isWindows()) ['media', 'play_pause']]),
          'btn1': ButtonConfig(name: 'Next', image: 'next.png',
              command: _isWindows() ? '' : 'playerctl next',
              hotkeys: [if (_isWindows()) ['media', 'next']]),
          'btn2': ButtonConfig(name: 'Previous', image: 'previous.png',
              command: _isWindows() ? '' : 'playerctl previous',
              hotkeys: [if (_isWindows()) ['media', 'previous']]),
          'btn3': ButtonConfig(name: 'Stop', image: 'stop.png',
              command: _isWindows() ? '' : 'playerctl stop'),
          'btn4': ButtonConfig(name: 'Vol Up', image: 'volume_up.png',
              command: _isWindows()
                  ? ''  // Handled via hotkey
                  : 'amixer set Master 5%+',
              hotkeys: [if (_isWindows()) ['volume_up']]),
          'btn5': ButtonConfig(name: 'Vol Down', image: 'volume_down.png',
              command: _isWindows() ? '' : 'amixer set Master 5%-',
              hotkeys: [if (_isWindows()) ['volume_down']]),
        }),
      ],
    );
  }

  bool _isWindows() => Platform.isWindows;
}
