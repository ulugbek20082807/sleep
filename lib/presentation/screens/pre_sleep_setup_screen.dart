import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';
import '../../logic/active_sleep_bloc/active_sleep_bloc.dart';
import '../../logic/active_sleep_bloc/active_sleep_event.dart';
import '../../logic/pre_sleep_setup_cubit/pre_sleep_setup_cubit.dart';
import '../../logic/pre_sleep_setup_cubit/pre_sleep_setup_state.dart';
import '../../logic/profile_bloc/profile_bloc.dart';
import '../../logic/profile_bloc/profile_event.dart';
import '../../services/hardware_volume_service.dart';
import '../../services/permission_gatekeeper_service.dart';
import '../widgets/pre_flight_permission_dialogs.dart';
import '../widgets/sound_calibration_card.dart';
import '../widgets/wake_health_indicator_bar.dart';
import 'active_sleep_tracking_screen.dart';

class PreSleepSetupScreen extends StatefulWidget {
  final AppUserProfileMeta activeProfile;
  final UserProfileModel userProfileModel;

  const PreSleepSetupScreen({
    super.key,
    required this.activeProfile,
    required this.userProfileModel,
  });

  @override
  State<PreSleepSetupScreen> createState() => _PreSleepSetupScreenState();
}

class _PreSleepSetupScreenState extends State<PreSleepSetupScreen> {
  final HardwareVolumeService _volumeService = HardwareVolumeService();
  late UserProfileModel _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _currentUserProfile = widget.userProfileModel;
  }

  Future<void> _startSleepSession(PreSleepSetupState setupState) async {
    // -------------------------------------------------------------------------
    // Phase 2: Pre-Flight Gatekeeper
    // -------------------------------------------------------------------------

    // Step 2.1: Background execution check (battery optimization)
    final isBatteryIgnored =
        await PermissionGatekeeperService.isBatteryOptimizationIgnored();
    if (!isBatteryIgnored && mounted) {
      final proceed =
          await PreFlightPermissionDialogs.showBatteryOptimizationDialog(context);
      if (!proceed) return;
    }

    // Step 2.2: Microphone permission check (only if analysis mode enabled)
    if (setupState.enableAnalysisMode) {
      final isMicGranted =
          await PermissionGatekeeperService.isMicrophoneGranted();
      if (!isMicGranted && mounted) {
        final proceed =
            await PreFlightPermissionDialogs.showMicrophoneRequiredDialog(context);
        if (!proceed) return;
      }
    }

    // Step 2.3: Reactive 70% hardware speaker volume check
    if (mounted) {
      final proceed =
          await PreFlightPermissionDialogs.showReactiveVolumeDialog(
        context,
        _volumeService,
      );
      if (!proceed) return;
    }

    if (!mounted) return;

    // All pre-flight checks passed! Start sleep session in ActiveSleepBloc
    final now = DateTime.now();
    DateTime normalizedWake = setupState.targetWakeTime;
    while (!normalizedWake.isAfter(now)) {
      normalizedWake = normalizedWake.add(const Duration(days: 1));
    }

    context.read<ActiveSleepBloc>().add(
          StartSleepSessionEvent(
            profileId: widget.activeProfile.id,
            sleepStartTime: now,
            targetWakeTime: normalizedWake,
            physicalState: setupState.physicalState,
            preset: setupState.preset,
            enableAnalysisMode: setupState.enableAnalysisMode,
            wakeHealthZoneAtStart: setupState.evaluation.healthZone,
          ),
        );

    // Navigate to active tracking, keeping MainShellScreen directly under it in back stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ActiveSleepTrackingScreen(
          activeProfile: widget.activeProfile,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Tonight’s Sleep Setup'),
      ),
      body: BlocBuilder<PreSleepSetupCubit, PreSleepSetupState>(
        builder: (context, state) {
          final cubit = context.read<PreSleepSetupCubit>();
          final timeStr = DateFormat('HH:mm').format(state.targetWakeTime);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Target Wake Time Card
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: state.targetWakeTime.hour,
                        minute: state.targetWakeTime.minute,
                      ),
                    );
                    if (picked != null) {
                      final now = DateTime.now();
                      DateTime newWake = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        picked.hour,
                        picked.minute,
                      );
                      if (!newWake.isAfter(now)) {
                        newWake = newWake.add(const Duration(days: 1));
                      }
                      cubit.updateWakeTime(newWake);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Wake-Up Time',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.alarm,
                            color: theme.colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Auto-Updating Wake Health & Alignment Indicator Bar (Directly after Wake Time)
              WakeHealthIndicatorBar(
                evaluation: state.evaluation,
                onSnapToIdealTime: () => cubit.snapToIdealWakeTime(),
              ),
              const SizedBox(height: 16),

              // 3. Sound Calibration Card (Universally accessible before sleep session)
              SoundCalibrationCard(
                initialGain: _currentUserProfile.calibrated30dBaAmplitude,
                onGainChanged: (newGain) {
                  _currentUserProfile = _currentUserProfile.copyWith(
                    calibrated30dBaAmplitude: newGain,
                  );
                  context.read<ProfileBloc>().add(
                        EditProfileEvent(
                          meta: widget.activeProfile,
                          updatedUserProfile: _currentUserProfile,
                        ),
                      );
                },
                volumeService: _volumeService,
                customSubtitle:
                    'Calibrate your pillow sound level for tonight.\n'
                    'Ensure device volume is set to 70% so procedural pink noise remains at optimal 30–44 dBA.',
              ),
              const SizedBox(height: 20),

              // 4. Physical State Selector
              Text(
                'Today’s Physical State',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PreSleepPhysicalState.values.map((pState) {
                  final isSelected = state.physicalState == pState;
                  String label;
                  IconData icon;
                  switch (pState) {
                    case PreSleepPhysicalState.normalBaseline:
                      label = 'Normal Baseline';
                      icon = Icons.check_circle_outline;
                      break;
                    case PreSleepPhysicalState.heavyWorkout:
                      label = 'Heavy Workout';
                      icon = Icons.fitness_center;
                      break;
                    case PreSleepPhysicalState.heavyMealBeforeBed:
                      label = 'Heavy Meal (<2h)';
                      icon = Icons.restaurant;
                      break;
                    case PreSleepPhysicalState.lowExhaustion:
                      label = 'Low Exhaustion';
                      icon = Icons.battery_charging_full;
                      break;
                    case PreSleepPhysicalState.highCognitiveLoad:
                      label = 'High Cognitive Load';
                      icon = Icons.psychology;
                      break;
                  }

                  return ChoiceChip(
                    avatar: Icon(icon, size: 16),
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => cubit.updatePhysicalState(pState),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 5. Sleep Goal Preset
              Text(
                'Sleep Goal Preset',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _PresetCard(
                title: 'Basic Balanced Sleep',
                description:
                    'Even balance across light, deep slow-wave and REM dreaming phases.',
                icon: Icons.balance,
                isSelected: state.preset == SleepPresetType.basicBalancedSleep,
                onTap: () =>
                    cubit.updatePreset(SleepPresetType.basicBalancedSleep),
              ),
              _PresetCard(
                title: 'Deep Sleep: Muscle Repair',
                description:
                    'Extends N3 slow-wave sleep with 0.8 Hz acoustic pink-noise pulses.',
                icon: Icons.healing,
                isSelected:
                    state.preset == SleepPresetType.deepSleepMuscleRepair,
                onTap: () =>
                    cubit.updatePreset(SleepPresetType.deepSleepMuscleRepair),
              ),
              _PresetCard(
                title: 'Deep Sleep: Cognitive & Memory',
                description:
                    'Deep sleep coupled with REM stabilization for memory consolidation.',
                icon: Icons.memory,
                isSelected:
                    state.preset == SleepPresetType.deepSleepCognitiveMemory,
                onTap: () =>
                    cubit.updatePreset(SleepPresetType.deepSleepCognitiveMemory),
              ),
              _PresetCard(
                title: 'Wake Up Fresh (Anti-Inertia)',
                description:
                    'Optimizes cycle trough landing with 30-min melodic priming to prevent grogginess.',
                icon: Icons.wb_sunny,
                isSelected:
                    state.preset == SleepPresetType.wakeUpFreshAntiInertia,
                onTap: () =>
                    cubit.updatePreset(SleepPresetType.wakeUpFreshAntiInertia),
              ),
              const SizedBox(height: 16),

              // 6. Analysis Mode Switch
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: SwitchListTile(
                  secondary: const Icon(Icons.mic_none),
                  title: const Text('Analysis Mode Tonight'),
                  subtitle: const Text(
                    'Listens for natural cycle boundary bedsheet rustles to adaptively calibrate your profile.',
                  ),
                  value: state.enableAnalysisMode,
                  onChanged: (val) => cubit.updateAnalysisMode(val),
                ),
              ),
              const SizedBox(height: 24),

              // Start Sleep Button
              FilledButton.icon(
                icon: const Icon(Icons.bedtime, size: 22),
                label: const Text(
                  'Start Sleep Session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _startSleepSession(state),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : null,
      ),
    );
  }
}
