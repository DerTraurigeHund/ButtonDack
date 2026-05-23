import 'package:flutter/material.dart';
import '../models/models.dart';

/// Dropdown-style profile switcher.
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.dashboard_customize,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: activeProfile.isNotEmpty && profiles.any((p) => p.name == activeProfile)
                  ? activeProfile
                  : profiles.first.name,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              items: profiles.map((profile) {
                return DropdownMenuItem<String>(
                  value: profile.name,
                  child: Text(profile.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
