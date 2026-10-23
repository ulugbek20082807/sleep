import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';
import '../../logic/pre_sleep_setup_cubit/pre_sleep_setup_cubit.dart';
import '../../logic/profile_bloc/profile_bloc.dart';
import '../../logic/profile_bloc/profile_event.dart';
import '../../logic/profile_bloc/profile_state.dart';
import '../../logic/sleep_history_cubit/sleep_history_cubit.dart';
import '../../logic/sleep_history_cubit/sleep_history_state.dart';
import '../widgets/profile_avatar_menu_button.dart';
import '../widgets/sleep_history_card.dart';
import 'create_edit_profile_screen.dart';
import 'pre_sleep_setup_screen.dart';
import 'scientific_profile_data_screen.dart';
import 'sleep_history_detail_screen.dart';
import 'switch_profiles_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialTab;

  const MainShellScreen({super.key, this.initialTab = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  void _navigateToSetup(
    BuildContext context,
    AppUserProfileMeta activeProfile,
    UserProfileModel userProfile,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => PreSleepSetupCubit(
            unifier: context.read<ProfileBloc>().unifier,
            initialWakeTime: DateTime.now().copyWith(
              hour: (userProfile.habitualWakeMin.round() ~/ 60) % 24,
              minute: userProfile.habitualWakeMin.round() % 60,
            ),
          ),
          child: PreSleepSetupScreen(
            activeProfile: activeProfile,
            userProfileModel: userProfile,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileZeroProfiles) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  const CreateEditProfileScreen(isFirstProfile: true),
            ),
            (route) => false,
          );
        } else if (state is ProfileLoaded) {
          // Keep history cubit synced with active profile
          context.read<SleepHistoryCubit>().loadHistory(state.activeProfile.id);
        }
      },
      builder: (context, state) {
        if (state is! ProfileLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final activeProfile = state.activeProfile;
        final userProfile = state.activeUserProfile;

        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTab == 0 ? 'Sleep History' : 'Profile & Settings',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  activeProfile.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              ProfileAvatarMenuButton(
                activeProfile: activeProfile,
                onOpenSwitchProfiles: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SwitchProfilesScreen(),
                    ),
                  );
                },
                onOpenSettings: () {
                  setState(() => _selectedTab = 1);
                },
                onOpenScientificData: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScientificProfileDataScreen(
                        meta: activeProfile,
                        profile: userProfile,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _selectedTab == 0
              ? _HistoryTab(
                  profileId: activeProfile.id,
                  onStartTapped: () =>
                      _navigateToSetup(context, activeProfile, userProfile),
                )
              : _SettingsTab(
                  meta: activeProfile,
                  profile: userProfile,
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton.large(
            shape: const CircleBorder(),
            elevation: 4,
            tooltip: 'Start Sleep',
            onPressed: () =>
                _navigateToSetup(context, activeProfile, userProfile),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bedtime, size: 36),
                SizedBox(height: 2),
                Text(
                  'Start',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(
                    _selectedTab == 0 ? Icons.history : Icons.history_outlined,
                    color: _selectedTab == 0 ? theme.colorScheme.primary : null,
                  ),
                  tooltip: 'Sleep History',
                  onPressed: () => setState(() => _selectedTab = 0),
                ),
                const SizedBox(width: 48), // Spacer for center FAB
                IconButton(
                  icon: Icon(
                    _selectedTab == 1 ? Icons.tune : Icons.tune_outlined,
                    color: _selectedTab == 1 ? theme.colorScheme.primary : null,
                  ),
                  tooltip: 'Settings',
                  onPressed: () => setState(() => _selectedTab = 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final String profileId;
  final VoidCallback onStartTapped;

  const _HistoryTab({
    required this.profileId,
    required this.onStartTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<SleepHistoryCubit, SleepHistoryState>(
      builder: (context, state) {
        if (state.status == SleepHistoryStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.records.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.nights_stay_outlined,
                    size: 72,
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sleep records yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the Start button below before bed to track your sleep cycle and enjoy procedural acoustic masking.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.bedtime),
                    label: const Text('Start Tonight’s Sleep'),
                    onPressed: onStartTapped,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          itemCount: state.records.length,
          itemBuilder: (context, index) {
            final record = state.records[index];
            return SleepHistoryCard(
              record: record,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SleepHistoryDetailScreen(record: record),
                  ),
                );
              },
              onDeleteConfirmed: () {
                context
                    .read<SleepHistoryCubit>()
                    .deleteSession(record.profileId, record.sessionId);
              },
            );
          },
        );
      },
    );
  }
}

class _SettingsTab extends StatefulWidget {
  final AppUserProfileMeta meta;
  final UserProfileModel profile;

  const _SettingsTab({required this.meta, required this.profile});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late double _arousalOffsetDb;
  late double _habitualBedtimeMin;
  late double _habitualWakeMin;

  @override
  void initState() {
    super.initState();
    _arousalOffsetDb = widget.profile.arousalThresholdOffsetDb;
    _habitualBedtimeMin = widget.profile.habitualBedtimeMin;
    _habitualWakeMin = widget.profile.habitualWakeMin;
  }

  void _saveUpdates() {
    final updatedProfile = widget.profile.copyWith(
      arousalThresholdOffsetDb: _arousalOffsetDb,
      habitualBedtimeMin: _habitualBedtimeMin,
      habitualWakeMin: _habitualWakeMin,
    );

    context.read<ProfileBloc>().add(EditProfileEvent(
          meta: widget.meta,
          updatedUserProfile: updatedProfile,
        ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  void _resetLearnedData() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset Learned Cycle Data?'),
          content: const Text(
            'This will reset your learned cycle length back to 90.0 minutes and reset Kalman filter variances.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(ctx).pop();
                final resetProfile = widget.profile.copyWith(
                  baselineCycleMinutes: 90.0,
                  completedAnalysisProbesCount: 0,
                  stateCycleDurationOffsetsMin: [0.0, 0.0, 0.0, 0.0, 0.0],
                  kalmanParameterVariances: [36.0, 12.0, 12.0, 12.0, 12.0],
                );
                context.read<ProfileBloc>().add(EditProfileEvent(
                      meta: widget.meta,
                      updatedUserProfile: resetProfile,
                    ));
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.profile;

    final bedtimeHour = (_habitualBedtimeMin.round() ~/ 60) % 24;
    final bedtimeMinute = _habitualBedtimeMin.round() % 60;
    final wakeHour = (_habitualWakeMin.round() ~/ 60) % 24;
    final wakeMinute = _habitualWakeMin.round() % 60;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        // Profile Info Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ProfileAvatarWidget(
                  avatarPath: widget.meta.avatarPath,
                  radius: 30,
                  initials: widget.meta.displayName,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.meta.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.ageYears} yrs • ${p.heightCm.round()} cm • ${p.weightKg.round()} kg (${p.bmi.toStringAsFixed(1)} BMI)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateEditProfileScreen(
                          existingMeta: widget.meta,
                          existingProfile: widget.profile,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Learned Cycle Length Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Learned Cycle Length',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        p.completedAnalysisProbesCount >= 3
                            ? 'High Confidence'
                            : 'Calibrating (${p.completedAnalysisProbesCount})',
                        style: theme.textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${p.baselineCycleMinutes.toStringAsFixed(1)} Minutes',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Measured through high-frequency bedsheet rustle spikes during Analysis Mode.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset Learned Data'),
                  onPressed: _resetLearnedData,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Master Sound Comfort Offset Slider
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sound & Probe Intensity',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_arousalOffsetDb >= 0 ? "+" : ""}${_arousalOffsetDb.toStringAsFixed(1)} dB',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust if nocturnal sounds feel too quiet (deep sleeper) or too loud (light sleeper).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Slider(
                  value: _arousalOffsetDb,
                  min: -6.0,
                  max: 6.0,
                  divisions: 24,
                  onChanged: (val) {
                    setState(() => _arousalOffsetDb = val);
                    _saveUpdates();
                  },
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quieter (-6dB)', style: TextStyle(fontSize: 11)),
                    Text('Default (0dB)', style: TextStyle(fontSize: 11)),
                    Text('Louder (+6dB)', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Circadian Schedule Tuning
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Habitual Circadian Anchors',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('Habitual Bedtime'),
                  trailing: Text(
                    '${bedtimeHour.toString().padLeft(2, '0')}:${bedtimeMinute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: bedtimeHour,
                        minute: bedtimeMinute,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _habitualBedtimeMin =
                            picked.hour * 60.0 + picked.minute;
                      });
                      _saveUpdates();
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Habitual Wake Time'),
                  trailing: Text(
                    '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: wakeHour,
                        minute: wakeMinute,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _habitualWakeMin =
                            picked.hour * 60.0 + picked.minute;
                      });
                      _saveUpdates();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Scientific Profile Data ("Menu for Nerds")
        Card(
          elevation: 0,
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              Icons.analytics_outlined,
              color: theme.colorScheme.secondary,
              size: 28,
            ),
            title: const Text(
              'Scientific Profile Data',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Circadian, acoustic & Kalman parameters with health indicators ("Menu for Nerds")',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ScientificProfileDataScreen(
                    meta: widget.meta,
                    profile: widget.profile,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Quick Link to Switch Profiles
        OutlinedButton.icon(
          icon: const Icon(Icons.switch_account),
          label: const Text('Manage & Switch Profiles'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SwitchProfilesScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
