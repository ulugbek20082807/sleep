import 'package:flutter/material.dart';
import '../../core/sleep_core_engine.dart';

class WakeHealthIndicatorBar extends StatelessWidget {
  final WakeTimeHealthEvaluation evaluation;
  final VoidCallback onSnapToIdealTime;

  const WakeHealthIndicatorBar({
    super.key,
    required this.evaluation,
    required this.onSnapToIdealTime,
  });

  Color _getZoneColor(BuildContext context, WakeTimeHealthZone zone) {
    switch (zone) {
      case WakeTimeHealthZone.greenOptimal:
        return Colors.green.shade600;
      case WakeTimeHealthZone.yellowCaution:
        return Colors.amber.shade700;
      case WakeTimeHealthZone.redWarning:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zoneColor = _getZoneColor(context, evaluation.healthZone);

    final idealHour =
        evaluation.nearestNaturalTroughWakeTime.hour.toString().padLeft(2, '0');
    final idealMin = evaluation.nearestNaturalTroughWakeTime.minute
        .toString()
        .padLeft(2, '0');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: zoneColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  evaluation.healthZone == WakeTimeHealthZone.greenOptimal
                      ? Icons.check_circle_outline
                      : evaluation.healthZone == WakeTimeHealthZone.yellowCaution
                          ? Icons.warning_amber_rounded
                          : Icons.error_outline,
                  color: zoneColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evaluation.statusHeadline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: zoneColor,
                    ),
                  ),
                ),
                Text(
                  '${(evaluation.healthScoreNormalized * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: zoneColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(
                begin: 0.0,
                end: evaluation.healthScoreNormalized.clamp(0.0, 1.0),
              ),
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(zoneColor),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              evaluation.statusSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                'Suggest Optimal Wake Time ($idealHour:$idealMin • ${evaluation.matchedCycleCount} Cycles)',
              ),
              onPressed: onSnapToIdealTime,
            ),
          ],
        ),
      ),
    );
  }
}

