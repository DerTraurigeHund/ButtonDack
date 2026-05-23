import 'package:flutter/material.dart';
import '../models/models.dart';

/// Icon-button style profile switcher for the app bar.
class ProfileSwitcher extends StatelessWidget {
  final List<Profile> profiles;
  final String activeProfile;
  final ValueChanged<String> onChanged;

  const ProfileSwitcher({
    super.key,
    required this.profiles,
    required this.activeProfile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.swap_horiz,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: 'Profile wechseln',
      onSelected: onChanged,
      itemBuilder: (ctx) => profiles.map((p) {
        final isActive = p.name == activeProfile ||
            (activeProfile.isEmpty && p == profiles.first);
        return PopupMenuItem<String>(
          value: p.name,
          child: Row(
            children: [
              Icon(
                Icons.folder,
                size: 18,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                p.name,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : Colors.grey.shade300,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Icon(Icons.check,
                    size: 16, color: Theme.of(context).colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
