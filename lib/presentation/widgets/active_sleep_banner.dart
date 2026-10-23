import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';
import '../../logic/active_sleep_bloc/active_sleep_bloc.dart';
import '../../logic/active_sleep_bloc/active_sleep_state.dart';
import '../screens/active_sleep_tracking_screen.dart';

class ActiveSleepBanner extends StatelessWidget {
  final AppUserProfileMeta activeProfile;

  const ActiveSleepBanner({super.key, required this.activeProfile});

  String _formatStage(PredictedSleepStage stage) {
    switch (stage) {
      case PredictedSleepStage.wakeOnset:
        return 'Wake Onset';
      case PredictedSleepStage.n1LightTransition:
        return 'N1 Light';
      case PredictedSleepStage.n2DescendingLight:
        return 'N2 Descending';
      case PredictedSleepStage.n3SlowWaveDeep:
        return 'N3 Deep Slow-Wave';
      case PredictedSleepStage.n2AscendingLight:
        return 'N2 Ascending';
      case PredictedSleepStage.remDreaming:
        return 'REM Dreaming';
      case PredictedSleepStage.postRemFragileTrough:
        return 'Fragile Trough';
      case PredictedSleepStage.preWakePriming:
        return 'Pre-Wake Priming';
    }
  }

  String _formatElapsed(Duration diff) {
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If ActiveSleepBloc is not in ancestor tree (e.g. isolated test environments), hide banner safely
    final ActiveSleepBloc? activeSleepBloc;
    try {
      activeSleepBloc = context.read<ActiveSleepBloc>();
    } catch (_) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<ActiveSleepBloc, ActiveSleepState>(
      bloc: activeSleepBloc,
      builder: (context, state) {
        if (state is! ActiveSleepRunning) {
          return const SizedBox.shrink();
        }

        final prediction = state.latestTickOutput.predictionFrame;
        final stageStr = _formatStage(prediction.predictedStage);
        final elapsedStr = _formatElapsed(state.elapsed);
        final wakeStr = DateFormat('HH:mm').format(state.targetWakeTime);

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          elevation: 3,
          color: theme.colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActiveSleepTrackingScreen(
                    activeProfile: activeProfile,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.nightlight_round,
                      color: theme.colorScheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Sleep Tracking Active',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stage: $stageStr • Elapsed: $elapsedStr • Wake: $wakeStr',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ActiveSleepTrackingScreen(
                            activeProfile: activeProfile,
                          ),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Return', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10),
                      ],
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

