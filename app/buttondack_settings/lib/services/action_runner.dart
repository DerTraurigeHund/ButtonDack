import 'dart:io';
import 'package:flutter/foundation.dart';

/// Result of an action execution.
class ActionResult {
  final bool success;
  final String output;
  final String? error;

  ActionResult({required this.success, this.output = '', this.error});

  Map<String, dynamic> toJson() => {
        'success': success,
        'output': output,
        if (error != null) 'error': error,
      };
}

/// Executes shell commands and simulates hotkeys on the host system.
class ActionRunner extends ChangeNotifier {
  /// Run a shell command.
  Future<ActionResult> runCommand(String command) async {
    if (command.trim().isEmpty) {
      return ActionResult(success: true, output: 'No command defined');
    }

    try {
      final result = await Process.run(
        Platform.isWindows ? 'cmd' : 'sh',
        Platform.isWindows ? ['/C', command] : ['-c', command],
        runInShell: true,
      );

      final output = (result.stdout as String).trim();
      final stderr = (result.stderr as String).trim();

      if (result.exitCode != 0) {
        return ActionResult(
          success: false,
          output: output,
          error: stderr.isNotEmpty ? stderr : 'Exit code: ${result.exitCode}',
        );
      }

      return ActionResult(success: true, output: output);
    } catch (e) {
      return ActionResult(
        success: false,
        error: 'Command failed: $e',
      );
    }
  }

  /// Press hotkey combinations.
  Future<ActionResult> pressHotkeys(List<List<String>> hotkeys) async {
    if (hotkeys.isEmpty) {
      return ActionResult(success: true, output: 'No hotkeys');
    }

    try {
      if (Platform.isLinux) {
        return _pressHotkeysLinux(hotkeys);
      } else if (Platform.isWindows) {
        return _pressHotkeysWindows(hotkeys);
      } else {
        return ActionResult(
          success: false,
          error: 'Unsupported OS: ${Platform.operatingSystem}',
        );
      }
    } catch (e) {
      return ActionResult(
        success: false,
        error: 'Hotkey failed: $e',
      );
    }
  }

  Future<ActionResult> _pressHotkeysLinux(List<List<String>> hotkeys) async {
    for (final combo in hotkeys) {
      final keySeq = combo.join('+');
      final result = await Process.run('xdotool', ['key', keySeq]);
      if (result.exitCode != 0) {
        return ActionResult(
          success: false,
          error: 'xdotool failed for $keySeq: ${result.stderr}',
        );
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return ActionResult(success: true, output: 'Hotkeys pressed');
  }

  Future<ActionResult> _pressHotkeysWindows(List<List<String>> hotkeys) async {
    for (final combo in hotkeys) {
      final keys = combo.map(_mapWinKey).join('');
      final psScript =
          '\$wshell = New-Object -ComObject wscript.shell; \$wshell.SendKeys(\'$keys\');';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', psScript],
      );
      if (result.exitCode != 0) {
        return ActionResult(
          success: false,
          error: 'SendKeys failed: ${result.stderr}',
        );
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return ActionResult(success: true, output: 'Hotkeys pressed');
  }

  String _mapWinKey(String key) {
    switch (key.toLowerCase()) {
      case 'ctrl':
        return '^';
      case 'alt':
        return '%';
      case 'shift':
        return '+';
      case 'win':
      case 'super':
      case 'meta':
        return '^{esc}';
      case 'volume_up':
        return '{VOLUME_UP}';
      case 'volume_down':
        return '{VOLUME_DOWN}';
      case 'media':
      case 'play_pause':
        return '{MEDIA_PLAY_PAUSE}';
      case 'next':
        return '{MEDIA_NEXT}';
      case 'previous':
      case 'prev':
        return '{MEDIA_PREV}';
      case 'stop':
        return '{MEDIA_STOP}';
      default:
        if (key.length == 1) return key.toUpperCase();
        return '{$key}';
    }
  }

  /// Execute a button's full action (hotkeys + command).
  Future<ActionResult> executeButton({
    required String? command,
    required List<List<String>> hotkeys,
    required bool withError,
  }) async {
    if (hotkeys.isNotEmpty) {
      final hkResult = await pressHotkeys(hotkeys);
      if (!hkResult.success && withError) return hkResult;
    }

    if (command != null && command.isNotEmpty) {
      final cmdResult = await runCommand(command);
      if (!cmdResult.success && withError) return cmdResult;
      return cmdResult;
    }

    return ActionResult(success: true, output: 'Action completed');
  }
}
