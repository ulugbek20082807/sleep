import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';
import '../../logic/active_sleep_bloc/active_sleep_bloc.dart';
import '../../logic/active_sleep_bloc/active_sleep_event.dart';
import '../../logic/active_sleep_bloc/active_sleep_state.dart';
import '../../logic/sleep_history_cubit/sleep_history_cubit.dart';
import '../widgets/hold_to_stop_button.dart';
import 'main_shell_screen.dart';

class ActiveSleepTrackingScreen extends StatelessWidget {
  final AppUserProfileMeta activeProfile;

  const ActiveSleepTrackingScreen({super.key, required this.activeProfile});

  String _formatStage(PredictedSleepStage stage) {
    switch (stage) {
      case PredictedSleepStage.wakeOnset:
        return 'Wake Onset';
      case PredictedSleepStage.n1LightTransition:
        return 'N1 Light Transition';
      case PredictedSleepStage.n2DescendingLight:
        return 'N2 Descending Light';
      case PredictedSleepStage.n3SlowWaveDeep:
        return 'N3 Deep Slow-Wave';
      case PredictedSleepStage.n2AscendingLight:
        return 'N2 Ascending Light';
      case PredictedSleepStage.remDreaming:
        return 'REM Dreaming';
      case PredictedSleepStage.postRemFragileTrough:
        return 'Post-REM Fragile Trough';
      case PredictedSleepStage.preWakePriming:
        return 'Pre-Wake Melodic Priming';
    }
  }

  Color _getStageColor(BuildContext context, PredictedSleepStage stage) {
    switch (stage) {
      case PredictedSleepStage.wakeOnset:
        return Colors.amber.shade700;
      case PredictedSleepStage.remDreaming:
        return Colors.deepPurple.shade400;
      case PredictedSleepStage.n3SlowWaveDeep:
        return Colors.indigo.shade600;
      case PredictedSleepStage.n1LightTransition:
      case PredictedSleepStage.n2DescendingLight:
      case PredictedSleepStage.n2AscendingLight:
      case PredictedSleepStage.postRemFragileTrough:
      case PredictedSleepStage.preWakePriming:
        return Colors.lightBlue.shade600;
    }
  }

  String _formatCountdown(Duration diff) {
    if (diff.isNegative) return '00:00:00';
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ActiveSleepBloc, ActiveSleepState>(
      listener: (context, state) {
        if (state is ActiveSleepAwaitingConfirmation) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Save Analysed Sleep Updates?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analysis Mode tracked your ultradian cycle boundaries tonight.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (state.measuredCycleDurationMin != null)
                      Text(
                        'Observed Cycle: ${state.measuredCycleDurationMin!.toStringAsFixed(1)} min',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Learned Cycle Length: ${state.previousProfile.baselineCycleMinutes.toStringAsFixed(1)}m → ${state.proposedProfile.baselineCycleMinutes.toStringAsFixed(1)}m',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calibration Probes: ${state.previousProfile.completedAnalysisProbesCount} → ${state.proposedProfile.completedAnalysisProbesCount}',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Apply these updates to your permanent sleep profile?',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context
                          .read<ActiveSleepBloc>()
                          .add(const ConfirmAnalysisDataEvent(accept: false));
                    },
                    child: const Text('Discard Updates'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context
                          .read<ActiveSleepBloc>()
                          .add(const ConfirmAnalysisDataEvent(accept: true));
                    },
                    child: const Text('Apply & Save'),
                  ),
                ],
              );
            },
          );
        } else if (state is ActiveSleepCompleted) {
          // Reload history for this profile
          context.read<SleepHistoryCubit>().loadHistory(activeProfile.id);
          if (state.wasShortSession) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Session under 1 cycle; baseline profile settings were preserved.',
                ),
              ),
            );
          } else if (state.profileWasUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated with tonight’s sleep analysis.'),
              ),
            );
          }
          // Navigate back to history
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MainShellScreen(initialTab: 0),
            ),
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        if (state is! ActiveSleepRunning) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final now = DateTime.now();
        final countdown = state.targetWakeTime.difference(now);
        final dateStr = DateFormat('EEEE, MMM d').format(now);
        final timeStr = DateFormat('HH:mm:ss').format(now);

        final prediction = state.latestTickOutput.predictionFrame;
        final analysis = state.latestTickOutput.analysisFrame;
        final recipe = state.latestTickOutput.mergedSpeakerRecipe;

        final stageColor = _getStageColor(context, prediction.predictedStage);

        return WithForegroundTask(
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Minimize (session continues in background)',
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const MainShellScreen(),
                      ),
                    );
                  }
                },
              ),
              title: Text('${activeProfile.displayName} — Overnight Session'),
              centerTitle: false,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Background Execution Safety Indicator
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tracking runs in background. You can navigate the app or lock your screen.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // 1. Clock & Wake Countdown Header
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  dateStr,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.alarm,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Wake at ${DateFormat('HH:mm').format(state.targetWakeTime)} (${_formatCountdown(countdown)} remaining)',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Current Sleep Cycle & Stage Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: stageColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Current Sleep Stage',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stageColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatStage(prediction.predictedStage),
                                        style: TextStyle(
                                          color: stageColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Cycle ${prediction.currentCycleIndex} of ${prediction.optimalTotalCyclesForWakeWindow}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${(prediction.cycleProgressFraction * 100).round()}% Completed',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: prediction.cycleProgressFraction
                                        .clamp(0.0, 1.0),
                                    minHeight: 10,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(stageColor),
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Real-Time Acoustic Engine Telemetry Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: theme.colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.volume_up,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Procedural Acoustic Engine',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _AcousticItem(
                                      label: 'Volume',
                                      value:
                                          '${recipe.targetVolumeDba.toStringAsFixed(1)} dBA',
                                    ),
                                    _AcousticItem(
                                      label: 'Filter Cutoff',
                                      value:
                                          '${recipe.lowPassCutoffHz.round()} Hz',
                                    ),
                                    _AcousticItem(
                                      label: 'Warmth (β)',
                                      value: recipe.spectralSlopeBeta
                                          .toStringAsFixed(2),
                                    ),
                                    _AcousticItem(
                                      label: 'N3 Pulses',
                                      value: recipe.enable50msN3Pulses
                                          ? 'Active'
                                          : 'Off',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Analysis Mode Status Card (if enabled)
                        if (state.enableAnalysisMode)
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: theme.colorScheme.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.graphic_eq,
                                          color: theme.colorScheme.secondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Acoustic Analysis Mode',
                                        style:
                                            theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (state.cycleCalibratedTonight)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.green.shade800,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Boundary Detected',
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _AcousticItem(
                                        label: 'State',
                                        value: analysis.currentMode.name,
                                      ),
                                      _AcousticItem(
                                        label: 'Room Floor',
                                        value:
                                            '${analysis.rollingHighFreqFloorDba.toStringAsFixed(1)} dBA',
                                      ),
                                      _AcousticItem(
                                        label: 'Live Mic (>2.5k)',
                                        value:
                                            '${analysis.currentHighFreqMicDba.toStringAsFixed(1)} dBA',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 5. Bottom 2-Second Hold-to-Stop Button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: HoldToStopButton(
                      onStopConfirmed: () {
                        context
                            .read<ActiveSleepBloc>()
                            .add(const StopSleepSessionEvent());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AcousticItem extends StatelessWidget {
  final String label;
  final String value;

  const _AcousticItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
