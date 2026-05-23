import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/daemon_service.dart';

/// A single button tile in the grid.
class ButtonTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => daemon.sendAction(profileName, buttonId),
      onLongPress: () => _showButtonInfo(context),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (button.image.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Image.asset(
                  'assets/icons/${button.image}',
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.touch_app,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Icon(
                  Icons.touch_app,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Text(
              button.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
              button.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (button.command.isNotEmpty) ...[
              Text('Command:', style: Theme.of(context).textTheme.labelMedium),
              Text(button.command, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
            ],
            if (button.hotkeys.isNotEmpty) ...[
              Text('Hotkeys:', style: Theme.of(context).textTheme.labelMedium),
              ...button.hotkeys.map(
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
                daemon.sendAction(profileName, buttonId);
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
