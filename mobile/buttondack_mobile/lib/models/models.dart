/// Data models for ButtonDack configuration and Spotify state.

class AppConfig {
  final DaemonConfig daemon;
  final SpotifyConfig spotify;
  final List<Profile> profiles;
  final String activeProfile;

  AppConfig({
    required this.daemon,
    required this.spotify,
    required this.profiles,
    this.activeProfile = '',
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      daemon: DaemonConfig.fromJson(json['daemon'] ?? {}),
      spotify: SpotifyConfig.fromJson(json['spotify'] ?? {}),
      profiles: (json['profiles'] as List<dynamic>?)
              ?.map((e) => Profile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      activeProfile: json['active_profile'] as String? ?? '',
    );
  }
}

class DaemonConfig {
  final String host;
  final int port;

  DaemonConfig({required this.host, required this.port});

  factory DaemonConfig.fromJson(Map<String, dynamic> json) {
    return DaemonConfig(
      host: json['host'] as String? ?? '0.0.0.0',
      port: json['port'] as int? ?? 42069,
    );
  }
}

class SpotifyConfig {
  final bool enabled;

  SpotifyConfig({required this.enabled});

  factory SpotifyConfig.fromJson(Map<String, dynamic> json) {
    return SpotifyConfig(
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

class Profile {
  final String name;
  final Map<String, ButtonConfig> buttons;

  Profile({required this.name, required this.buttons});

  factory Profile.fromJson(Map<String, dynamic> json) {
    final buttonsRaw = json['buttons'] as Map<String, dynamic>? ?? {};
    final buttons = <String, ButtonConfig>{};
    buttonsRaw.forEach((key, value) {
      buttons[key] = ButtonConfig.fromJson(value as Map<String, dynamic>);
    });
    return Profile(
      name: json['name'] as String? ?? '',
      buttons: buttons,
    );
  }
}

class ButtonConfig {
  final String name;
  final String bgImage;
  final String logoImage;
  final String bgColor;
  final String command;
  final List<List<String>> hotkeys;
  final bool withError;

  ButtonConfig({
    required this.name,
    this.bgImage = '',
    this.logoImage = '',
    this.bgColor = '',
    this.command = '',
    this.hotkeys = const [],
    this.withError = false,
  });

  factory ButtonConfig.fromJson(Map<String, dynamic> json) {
    return ButtonConfig(
      name: json['name'] as String? ?? '',
      bgImage: json['bg_image'] as String? ?? '',
      logoImage: json['logo_image'] as String? ?? '',
      bgColor: json['bg_color'] as String? ?? '',
      command: json['command'] as String? ?? '',
      hotkeys: _parseHotkeys(json['hotkeys']),
      withError: json['with_error'] as bool? ?? false,
    );
  }

  static List<List<String>> _parseHotkeys(dynamic hotkeys) {
    if (hotkeys == null) return [];
    if (hotkeys is List) {
      return hotkeys
          .map((e) => (e as List).map((k) => k.toString()).toList())
          .toList();
    }
    return [];
  }
}

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

  factory TrackInfo.fromJson(Map<String, dynamic> json) {
    return TrackInfo(
      isPlaying: json['is_playing'] as bool? ?? false,
      trackName: json['track_name'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      albumName: json['album_name'] as String? ?? '',
      albumArtUrl: json['album_art_url'] as String? ?? '',
      progressMs: json['progress_ms'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
      trackUrl: json['track_url'] as String? ?? '',
    );
  }
}
