import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/sleep_session_record.dart';
import '../../logic/profile_bloc/profile_bloc.dart';
import '../../logic/profile_bloc/profile_state.dart';
import '../widgets/active_sleep_banner.dart';

class SleepHistoryDetailScreen extends StatelessWidget {
  final SleepSessionRecord record;

  const SleepHistoryDetailScreen({super.key, required this.record});

  String _formatDuration(double minutes) {
    final int h = minutes ~/ 60;
    final int m = (minutes % 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatPhysicalState(PreSleepPhysicalState state) {
    switch (state) {
      case PreSleepPhysicalState.normalBaseline:
        return 'Normal Baseline';
      case PreSleepPhysicalState.heavyWorkout:
        return 'Heavy Workout';
      case PreSleepPhysicalState.heavyMealBeforeBed:
        return 'Heavy Meal (<2h)';
      case PreSleepPhysicalState.lowExhaustion:
        return 'Low Exhaustion';
      case PreSleepPhysicalState.highCognitiveLoad:
        return 'High Cognitive Load';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(record.sleepStartTime);
    final startStr = DateFormat('HH:mm').format(record.sleepStartTime);
    final endStr = DateFormat('HH:mm').format(record.actualEndTime);

    final totalMin = math.max(1.0, record.totalElapsedMinutes);
    final solMin = record.predictedSolMinutes;
    final lightMin = record.stageMinutesSummary['lightN1N2'] ?? 0.0;
    final deepMin = record.stageMinutesSummary['deepN3'] ?? 0.0;
    final remMin = record.stageMinutesSummary['remDreaming'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Sleep Session Details'),
      ),
      body: Builder(
        builder: (context) {
          final profileState = context.watch<ProfileBloc>().state;
          final activeProfile =
              profileState is ProfileLoaded ? profileState.activeProfile : null;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (activeProfile != null)
                ActiveSleepBanner(activeProfile: activeProfile),
              // 1. Top Summary Card
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
                    dateStr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$startStr to $endStr',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Total In Bed',
                        value: _formatDuration(record.totalElapsedMinutes),
                        icon: Icons.hotel_outlined,
                      ),
                      _StatColumn(
                        label: 'Net Asleep',
                        value: _formatDuration(record.netSleepMinutes),
                        icon: Icons.bedtime_outlined,
                      ),
                      _StatColumn(
                        label: 'Cycles',
                        value: '${record.completedCyclesCount}',
                        icon: Icons.replay_circle_filled_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.fitness_center, size: 16),
                        label: Text(_formatPhysicalState(record.physicalStateUsed)),
                      ),
                      Chip(
                        avatar: const Icon(Icons.music_note, size: 16),
                        label: Text(record.presetUsed.name),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Stage Distribution Breakdown Card
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
                    'Sleep Architecture Distribution',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StageProgressBar(
                    title: 'Sleep Onset Latency (SOL)',
                    minutes: solMin,
                    percentage: (solMin / totalMin) * 100,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(height: 12),
                  _StageProgressBar(
                    title: 'Light Sleep (N1 / N2)',
                    minutes: lightMin,
                    percentage: (lightMin / totalMin) * 100,
                    color: Colors.lightBlue.shade400,
                  ),
                  const SizedBox(height: 12),
                  _StageProgressBar(
                    title: 'Deep Slow-Wave Sleep (N3)',
                    minutes: deepMin,
                    percentage: (deepMin / totalMin) * 100,
                    color: Colors.indigo.shade600,
                  ),
                  const SizedBox(height: 12),
                  _StageProgressBar(
                    title: 'REM Dreaming',
                    minutes: remMin,
                    percentage: (remMin / totalMin) * 100,
                    color: Colors.deepPurple.shade400,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Hypnogram & Acoustic dBA Timeline Card
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
                    'Hypnogram & Audio Timeline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Predicted sleep depth stages across the session with procedural masking volume.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _HypnogramChartPainter(
                        samples: record.stageTimelineSamples,
                        theme: theme,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _LegendItem(color: Colors.amber.shade600, label: 'Wake'),
                      _LegendItem(color: Colors.deepPurple.shade400, label: 'REM'),
                      _LegendItem(color: Colors.lightBlue.shade400, label: 'Light'),
                      _LegendItem(color: Colors.indigo.shade600, label: 'Deep N3'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Circadian & Analysis Mode Telemetry Card
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
                    'Engine & Analysis Telemetry',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Circadian Shift (Δt_circ)'),
                    trailing: Text(
                      '${record.circadianShiftHours >= 0 ? "+" : ""}${record.circadianShiftHours.toStringAsFixed(1)} hours',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mic),
                    title: const Text('Analysis Mode'),
                    trailing: Text(
                      record.analysisModeEnabled ? 'Enabled' : 'Disabled',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (record.analysisModeEnabled) ...[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_graph),
                      title: const Text('Cycle Boundary Calibrated'),
                      trailing: Text(
                        record.cycleBoundaryCalibrated ? 'Yes' : 'No Boundary Spike',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: record.cycleBoundaryCalibrated
                              ? Colors.green.shade600
                              : null,
                        ),
                      ),
                    ),
                    if (record.measuredCycleDurationMinutes != null)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.speed),
                        title: const Text('Debiased Measured Cycle Length'),
                        trailing: Text(
                          '${record.measuredCycleDurationMinutes!.toStringAsFixed(1)} min',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    },
  ),
);
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StageProgressBar extends StatelessWidget {
  final String title;
  final double minutes;
  final double percentage;
  final Color color;

  const _StageProgressBar({
    required this.title,
    required this.minutes,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.bodyMedium),
            Text(
              '${minutes.round()} min (${percentage.round()}%)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            minHeight: 8,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _HypnogramChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> samples;
  final ThemeData theme;

  _HypnogramChartPainter({required this.samples, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final bgPaint = Paint()
      ..color = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    // 4 stages on Y-axis:
    // 0: Wake (top), 1: REM, 2: Light, 3: Deep (bottom)
    double stageToY(String stage) {
      switch (stage) {
        case 'wakeOnset':
          return size.height * 0.15;
        case 'remDreaming':
          return size.height * 0.40;
        case 'n1LightTransition':
        case 'n2DescendingLight':
        case 'n2AscendingLight':
        case 'postRemFragileTrough':
        case 'preWakePriming':
          return size.height * 0.65;
        case 'n3SlowWaveDeep':
          return size.height * 0.90;
        default:
          return size.height * 0.65;
      }
    }

    final linePaint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = theme.colorScheme.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final maxMin = samples.last['min'] as int? ?? 1;
    final double safeMaxMin = maxMin <= 0 ? 1.0 : maxMin.toDouble();

    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final min = (sample['min'] as num).toDouble();
      final stage = sample['stage'] as String;

      final x = (min / safeMaxMin) * size.width;
      final y = stageToY(stage);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _HypnogramChartPainter oldDelegate) => true;
}

