import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/sleep_session_record.dart';

class SleepHistoryCard extends StatefulWidget {
  final SleepSessionRecord record;
  final VoidCallback onTap;
  final VoidCallback onDeleteConfirmed;

  const SleepHistoryCard({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDeleteConfirmed,
  });

  @override
  State<SleepHistoryCard> createState() => _SleepHistoryCardState();
}

class _SleepHistoryCardState extends State<SleepHistoryCard> {
  bool _isRemoveActionVisible = false;

  String _formatDuration(double totalMinutes) {
    final int hours = totalMinutes ~/ 60;
    final int mins = (totalMinutes % 60).round();
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String _formatPreset(SleepPresetType preset) {
    switch (preset) {
      case SleepPresetType.deepSleepMuscleRepair:
        return 'Muscle Repair';
      case SleepPresetType.deepSleepCognitiveMemory:
        return 'Cognitive';
      case SleepPresetType.basicBalancedSleep:
        return 'Balanced';
      case SleepPresetType.wakeUpFreshAntiInertia:
        return 'Wake Fresh';
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove Sleep Record'),
          content: const Text(
            'Remove this sleep record from your history? This action cannot be undone.',
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
                widget.onDeleteConfirmed();
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;

    final dateStr = DateFormat('EEE, MMM d').format(record.sleepStartTime);
    final startStr = DateFormat('HH:mm').format(record.sleepStartTime);
    final endStr = DateFormat('HH:mm').format(record.actualEndTime);

    final n3Minutes = record.stageMinutesSummary['deepN3'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: () {
          setState(() {
            _isRemoveActionVisible = !_isRemoveActionVisible;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Date & Preset Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$startStr – $endStr',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text(
                      _formatPreset(record.presetUsed),
                      style: theme.textTheme.labelSmall,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Metrics Row: Duration, Cycles, Deep Sleep, Calibration Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetricItem(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(record.totalElapsedMinutes),
                  ),
                  _MetricItem(
                    icon: Icons.replay_circle_filled_outlined,
                    label: 'Cycles',
                    value: '${record.completedCyclesCount} Cycles',
                  ),
                  _MetricItem(
                    icon: Icons.waves,
                    label: 'Deep N3',
                    value: _formatDuration(n3Minutes),
                  ),
                  if (record.cycleBoundaryCalibrated)
                    Tooltip(
                      message: 'Calibrated cycle boundary tonight',
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_graph,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              // Animated Deletion Action Strip
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _isRemoveActionVisible
                    ? Column(
                        children: [
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isRemoveActionVisible = false;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.delete_forever, size: 18),
                                label: const Text('Remove Session'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      theme.colorScheme.errorContainer,
                                  foregroundColor:
                                      theme.colorScheme.onErrorContainer,
                                ),
                                onPressed: () =>
                                    _showDeleteConfirmation(context),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

