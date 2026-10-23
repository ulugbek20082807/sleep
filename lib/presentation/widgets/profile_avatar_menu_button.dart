import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/app_user_profile_meta.dart';

class ProfileAvatarWidget extends StatelessWidget {
  final String? avatarPath;
  final double radius;
  final String? initials;

  const ProfileAvatarWidget({
    super.key,
    this.avatarPath,
    this.radius = 20,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(file),
        );
      }
    }

    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: initials != null && initials!.trim().isNotEmpty
          ? Text(
              initials!.trim().substring(0, 1).toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            )
          : Icon(
              Icons.person_outline,
              size: radius * 1.1,
              color: theme.colorScheme.onPrimaryContainer,
            ),
    );
  }
}

class ProfileAvatarMenuButton extends StatelessWidget {
  final AppUserProfileMeta activeProfile;
  final VoidCallback onOpenSwitchProfiles;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenScientificData;

  const ProfileAvatarMenuButton({
    super.key,
    required this.activeProfile,
    required this.onOpenSwitchProfiles,
    required this.onOpenSettings,
    this.onOpenScientificData,
  });

  void _showProfileModal(BuildContext context) {
    final theme = Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.025,
            vertical: 24,
          ),
          contentPadding: const EdgeInsets.only(top: 20, bottom: 8),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          title: SizedBox(
            width: screenWidth * 0.95,
            child: Column(
              children: [
                ProfileAvatarWidget(
                  avatarPath: activeProfile.avatarPath,
                  radius: 36,
                  initials: activeProfile.displayName,
                ),
                const SizedBox(height: 12),
                Text(
                  activeProfile.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Active Profile',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: screenWidth * 0.95,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.switch_account),
                  title: const Text('Switch / Edit Profiles'),
                  subtitle: const Text('Manage your sleep profiles'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onOpenSwitchProfiles();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Profile & App Settings'),
                  subtitle: const Text('Tuning, bedtime & calibration'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onOpenSettings();
                  },
                ),
                if (onOpenScientificData != null)
                  ListTile(
                    leading: const Icon(Icons.analytics_outlined),
                    title: const Text('Scientific Data (Menu for Nerds)'),
                    subtitle: const Text(
                      'Ultradian curves, Kalman variances & DSP telemetry',
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onOpenScientificData!();
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: IconButton(
        icon: ProfileAvatarWidget(
          avatarPath: activeProfile.avatarPath,
          radius: 18,
          initials: activeProfile.displayName,
        ),
        tooltip: 'Profile Account Menu',
        onPressed: () => _showProfileModal(context),
      ),
    );
  }
}

