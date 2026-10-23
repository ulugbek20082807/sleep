import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';
import '../../data/repositories/profile_repository.dart';
import '../../logic/profile_bloc/profile_bloc.dart';
import '../../logic/profile_bloc/profile_event.dart';
import '../../logic/profile_bloc/profile_state.dart';
import '../widgets/profile_avatar_menu_button.dart';
import 'create_edit_profile_screen.dart';

class SwitchProfilesScreen extends StatelessWidget {
  const SwitchProfilesScreen({super.key});

  void _showDeleteConfirmation(
    BuildContext context,
    AppUserProfileMeta meta,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Profile?'),
          content: Text(
            'Delete profile "${meta.displayName}" and all its sleep history? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context
                    .read<ProfileBloc>()
                    .add(DeleteProfileEvent(profileId: meta.id));
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileZeroProfiles) {
          // Pop back to root so MainShellScreen executes the zero-profile redirect cleanly
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! ProfileLoaded) {
          return Scaffold(
            appBar: AppBar(
              centerTitle: false,
              title: const Text('Profiles'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final profiles = state.profiles;
        final activeId = state.activeProfile.id;
        final profileRepo = context.read<ProfileRepository>();

        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: const Text('Switch / Edit Profiles'),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final meta = profiles[index];
              final isActive = meta.id == activeId;

              return FutureBuilder<UserProfileModel?>(
                future: profileRepo.getUserProfileModel(meta.id),
                builder: (context, snapshot) {
                  final userProfile = snapshot.data;
                  final cycleMin =
                      userProfile?.baselineCycleMinutes.toStringAsFixed(1) ??
                          '90.0';
                  final probes =
                      userProfile?.completedAnalysisProbesCount ?? 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: isActive ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: isActive ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: ProfileAvatarWidget(
                        avatarPath: meta.avatarPath,
                        radius: 24,
                        initials: meta.displayName,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              meta.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isActive)
                            Chip(
                              label: const Text('Active'),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '$cycleMin min cycle • $probes calibrations',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit Profile',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreateEditProfileScreen(
                                    existingMeta: meta,
                                    existingProfile: userProfile,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete Profile',
                            onPressed: () =>
                                _showDeleteConfirmation(context, meta),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!isActive) {
                          context
                              .read<ProfileBloc>()
                              .add(SwitchProfileEvent(targetProfileId: meta.id));
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.person_add),
            label: const Text('Add Profile'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateEditProfileScreen(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

