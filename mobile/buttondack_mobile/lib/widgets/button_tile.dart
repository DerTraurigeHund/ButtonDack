import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/daemon_service.dart';

/// A single button tile in the grid.
/// Supports background image, background color, logo overlay, and press feedback.
class ButtonTile extends StatefulWidget {
  final String buttonId;
  final ButtonConfig button;
  final DaemonService daemon;
  final String profileName;

  const ButtonTile({
    super.key,
    required this.buttonId,
    required this.button,
    required this.daemon,
    required this.profileName,
  });

  @override
  State<ButtonTile> createState() => _ButtonTileState();
}

class _ButtonTileState extends State<ButtonTile> {
  /// null = idle, true = success flash, false = error flash
  bool? _feedbackState;
  Timer? _feedbackTimer;

  StreamSubscription<ActionResult>? _actionSub;

  @override
  void initState() {
    super.initState();
    // Listen for action results to show feedback
    _actionSub = widget.daemon.actionResults.listen((result) {
      if (!mounted) return;
      setState(() => _feedbackState = result.success);
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _feedbackState = null);
      });
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _actionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btn = widget.button;

    // Determine background color
    Color? backgroundColor;
    if (btn.bgColor.isNotEmpty) {
      final hex = btn.bgColor.replaceFirst('#', '');
      if (hex.length == 6) {
        backgroundColor = Color(int.parse('FF$hex', radix: 16));
      }
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    }

    // Override with feedback colors
    Color? feedbackOverlay;
    if (_feedbackState == true) {
      feedbackOverlay = Colors.green.withValues(alpha: 0.35);
    } else if (_feedbackState == false) {
      feedbackOverlay = Colors.red.withValues(alpha: 0.35);
    }

    return GestureDetector(
      onTap: () => widget.daemon.sendAction(
          widget.profileName, widget.buttonId),
      onLongPress: () => _showButtonInfo(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- Layer 1: Background image or color ---
            if (btn.bgImage.isNotEmpty)
              Image.asset(
                'assets/backgrounds/${btn.bgImage}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildColorBackground(backgroundColor),
              )
            else
              _buildColorBackground(backgroundColor),

            // --- Layer 2: Feedback overlay ---
            if (feedbackOverlay != null)
              Positioned.fill(
                child: Container(color: feedbackOverlay),
              ),

            // --- Layer 3: Logo image ---
            if (btn.logoImage.isNotEmpty)
              Positioned.fill(
                child: Center(
                  child: Image.asset(
                    'assets/logos/${btn.logoImage}',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _buildLogoFallback(btn.name),
                  ),
                ),
              )
            else
              // Show name as fallback when no logo
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      btn.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textColorForBackground(backgroundColor),
                        shadows: const [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

            // --- Layer 4: Button name at bottom (only if logo shown) ---
            if (btn.logoImage.isNotEmpty)
              Positioned(
                left: 4,
                right: 4,
                bottom: 6,
                child: Text(
                  btn.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _textColorForBackground(backgroundColor),
                    shadows: const [
                      Shadow(blurRadius: 3, color: Colors.black54),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorBackground(Color? color) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade800,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildLogoFallback(String name) {
    // Show first letter as avatar-style fallback
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Color _textColorForBackground(Color? bg) {
    if (bg == null) return Colors.white;
    // Simple luminance check for text contrast
    final l = bg.computeLuminance();
    return l > 0.5 ? Colors.black87 : Colors.white;
  }

  void _showButtonInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.button.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (widget.button.command.isNotEmpty) ...[
              Text('Command:',
                  style: Theme.of(context).textTheme.labelMedium),
              Text(widget.button.command,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
            ],
            if (widget.button.hotkeys.isNotEmpty) ...[
              Text('Hotkeys:',
                  style: Theme.of(context).textTheme.labelMedium),
              ...widget.button.hotkeys.map(
                (hk) => Text(
                  hk.join(' + ').toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                widget.daemon.sendAction(
                    widget.profileName, widget.buttonId);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Execute'),
            ),
          ],
        ),
      ),
    );
  }
}
