import 'package:flutter/material.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';

class ScientificProfileDataScreen extends StatelessWidget {
  final AppUserProfileMeta meta;
  final UserProfileModel profile;

  const ScientificProfileDataScreen({
    super.key,
    required this.meta,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compute health scores for key metrics
    // 1. Cycle Length Health (Optimal: 85 - 100 min)
    final double cycleLen = profile.baselineCycleMinutes;
    double cycleScore;
    if (cycleLen >= 85 && cycleLen <= 100) {
      cycleScore = 1.0;
    } else if (cycleLen >= 75 && cycleLen <= 110) {
      cycleScore = 0.65;
    } else {
      cycleScore = 0.30;
    }

    // 2. SOL Health (Optimal: 10 - 25 min)
    final double sol = profile.baselineSolMinutes;
    double solScore;
    if (sol >= 10 && sol <= 25) {
      solScore = 1.0;
    } else if (sol >= 5 && sol <= 35) {
      solScore = 0.65;
    } else {
      solScore = 0.30;
    }

    // 3. BMI Health (Optimal: 18.5 - 24.9)
    final double bmi = profile.bmi;
    double bmiScore;
    if (bmi >= 18.5 && bmi <= 24.9) {
      bmiScore = 1.0;
    } else if (bmi >= 17.0 && bmi <= 29.9) {
      bmiScore = 0.65;
    } else {
      bmiScore = 0.30;
    }

    // 4. Kalman Confidence (Variances <= 12 is high confidence)
    final double cycleVar = profile.kalmanParameterVariances.isNotEmpty
        ? profile.kalmanParameterVariances[0]
        : 36.0;
    double confidenceScore =
        (1.0 - (cycleVar / 40.0)).clamp(0.1, 1.0);

    final bedtimeH = (profile.habitualBedtimeMin.round() ~/ 60) % 24;
    final bedtimeM = profile.habitualBedtimeMin.round() % 60;
    final wakeH = (profile.habitualWakeMin.round() ~/ 60) % 24;
    final wakeM = profile.habitualWakeMin.round() % 60;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Scientific Profile Data (Menu for Nerds)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header Card
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${meta.displayName}’s Sleep Engine Parameters',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time physiological parameters, regression constants, and Kalman filter covariance matrix driving your acoustic sleep modulator.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 1. Ultradian Sleep Architecture
          _SectionCard(
            title: '1. Ultradian Cycle Architecture',
            icon: Icons.replay_circle_filled,
            children: [
              _MetricWithHealthBar(
                label: 'Baseline Cycle Length (τ_user)',
                value: '${cycleLen.toStringAsFixed(1)} min',
                score: cycleScore,
                optimalRange: 'Normative: 85.0 – 100.0 min',
              ),
              const Divider(height: 24),
              _MetricRow(
                label: 'Cycle Progression Slope (c1)',
                value:
                    '+${profile.linearCycleCurveCoeff.toStringAsFixed(2)} min/cycle',
                description: 'Lengthens later sleep cycles naturally across the night',
              ),
              const SizedBox(height: 10),
              _MetricRow(
                label: 'Cycle 1 Deep SWS Share',
                value:
                    '${(profile.baseN3FractionCycle1 * 100).toStringAsFixed(1)}%',
                description: 'Initial slow-wave sleep concentration',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Sleep Onset & Circadian Anchors
          _SectionCard(
            title: '2. Sleep Onset & Circadian Dynamics',
            icon: Icons.schedule,
            children: [
              _MetricWithHealthBar(
                label: 'Baseline Sleep Onset Latency (SOL)',
                value: '${sol.toStringAsFixed(1)} min',
                score: solScore,
                optimalRange: 'Optimal: 10.0 – 25.0 min',
              ),
              const Divider(height: 24),
              _MetricRow(
                label: 'Habitual Bedtime',
                value:
                    '${bedtimeH.toString().padLeft(2, '0')}:${bedtimeM.toString().padLeft(2, '0')}',
                description: 'Circadian phase reference anchor',
              ),
              const SizedBox(height: 10),
              _MetricRow(
                label: 'Habitual Wake Time',
                value:
                    '${wakeH.toString().padLeft(2, '0')}:${wakeM.toString().padLeft(2, '0')}',
                description: 'Ultradian reset target anchor',
              ),
              const SizedBox(height: 10),
              const _MetricRow(
                label: 'Wake Maintenance Zone (WMZ)',
                value: '-4.5h to -0.25h before bedtime',
                description: 'High cortical arousal window where sleep is naturally resisted',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Psychoacoustics & Calibration
          _SectionCard(
            title: '3. Acoustic Synthesis & Calibration',
            icon: Icons.graphic_eq,
            children: [
              _MetricWithHealthBar(
                label: 'Calibrated 30 dBA Digital Gain',
                value: profile.calibrated30dBaAmplitude.toStringAsFixed(4),
                score: 1.0,
                optimalRange: 'Hardware sweet-spot: 0.0020 – 0.0300',
              ),
              const Divider(height: 24),
              _MetricRow(
                label: 'Arousal Sensitivity Offset',
                value:
                    '${profile.arousalThresholdOffsetDb >= 0 ? "+" : ""}${profile.arousalThresholdOffsetDb.toStringAsFixed(1)} dB',
                description: 'Adjusts acoustic masking ceiling for light vs deep sleepers',
              ),
              const SizedBox(height: 10),
              const _MetricRow(
                label: 'Hardware Volume Standard',
                value: '70% Media Volume (±5%)',
                description: 'Linear Class-D speaker amplification zone',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Physical State Covariates Matrix
          _SectionCard(
            title: '4. Physical State Covariates (β_state)',
            icon: Icons.fitness_center,
            children: [
              Text(
                'Dynamic offsets applied when pre-sleep physical state is selected tonight:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _StateCovariateTile(
                stateName: 'Normal Baseline',
                cycleOffsetMin: 0.0,
                solMultiplier: 1.0,
                n3Multiplier: 1.0,
              ),
              _StateCovariateTile(
                stateName: 'Heavy Workout',
                cycleOffsetMin: profile.stateCycleDurationOffsetsMin.length > 1
                    ? profile.stateCycleDurationOffsetsMin[1]
                    : 4.0,
                solMultiplier: profile.stateSolMultipliers.length > 1
                    ? profile.stateSolMultipliers[1]
                    : -0.25,
                n3Multiplier: profile.stateN3Multipliers.length > 1
                    ? profile.stateN3Multipliers[1]
                    : 1.30,
              ),
              _StateCovariateTile(
                stateName: 'Heavy Meal (<2h)',
                cycleOffsetMin: profile.stateCycleDurationOffsetsMin.length > 2
                    ? profile.stateCycleDurationOffsetsMin[2]
                    : -3.0,
                solMultiplier: profile.stateSolMultipliers.length > 2
                    ? profile.stateSolMultipliers[2]
                    : 0.40,
                n3Multiplier: profile.stateN3Multipliers.length > 2
                    ? profile.stateN3Multipliers[2]
                    : 0.85,
              ),
              _StateCovariateTile(
                stateName: 'Low Exhaustion',
                cycleOffsetMin: profile.stateCycleDurationOffsetsMin.length > 3
                    ? profile.stateCycleDurationOffsetsMin[3]
                    : -5.0,
                solMultiplier: profile.stateSolMultipliers.length > 3
                    ? profile.stateSolMultipliers[3]
                    : 0.50,
                n3Multiplier: profile.stateN3Multipliers.length > 3
                    ? profile.stateN3Multipliers[3]
                    : 0.70,
              ),
              _StateCovariateTile(
                stateName: 'High Cognitive Load',
                cycleOffsetMin: profile.stateCycleDurationOffsetsMin.length > 4
                    ? profile.stateCycleDurationOffsetsMin[4]
                    : 2.0,
                solMultiplier: profile.stateSolMultipliers.length > 4
                    ? profile.stateSolMultipliers[4]
                    : 0.30,
                n3Multiplier: profile.stateN3Multipliers.length > 4
                    ? profile.stateN3Multipliers[4]
                    : 1.15,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Kalman Filter Parameter Confidence
          _SectionCard(
            title: '5. Kalman Filter Covariance Matrix (P)',
            icon: Icons.auto_graph,
            children: [
              _MetricWithHealthBar(
                label: 'Cycle Parameter Confidence (1/σ²)',
                value: '${(confidenceScore * 100).round()}%',
                score: confidenceScore,
                optimalRange:
                    'Cycle Variance: ${cycleVar.toStringAsFixed(1)} (Completed: ${profile.completedAnalysisProbesCount} probes)',
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0;
                      i < profile.kalmanParameterVariances.length;
                      i++)
                    Chip(
                      label: Text(
                        'P[$i]: ${profile.kalmanParameterVariances[i].toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6. Anthropometrics
          _SectionCard(
            title: '6. Physique & Anthropometrics',
            icon: Icons.person_outline,
            children: [
              _MetricWithHealthBar(
                label: 'Body Mass Index (BMI)',
                value: bmi.toStringAsFixed(1),
                score: bmiScore,
                optimalRange: 'Normal: 18.5 – 24.9',
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _MetricRow(
                      label: 'Age',
                      value: '${profile.ageYears} yrs',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricRow(
                      label: 'Sex',
                      value: profile.sex.name,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricRow(
                      label: 'Height',
                      value: '${profile.heightCm.round()} cm',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricRow(
                      label: 'Weight',
                      value: '${profile.weightKg.round()} kg',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
                Icon(icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricWithHealthBar extends StatelessWidget {
  final String label;
  final String value;
  final double score;
  final String optimalRange;

  const _MetricWithHealthBar({
    required this.label,
    required this.value,
    required this.score,
    required this.optimalRange,
  });

  Color _getColor(BuildContext context) {
    if (score >= 0.75) return Colors.green.shade600;
    if (score >= 0.45) return Colors.amber.shade700;
    return Theme.of(context).colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score.clamp(0.0, 1.0),
            minHeight: 8,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          optimalRange,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String? description;

  const _MetricRow({
    required this.label,
    required this.value,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _StateCovariateTile extends StatelessWidget {
  final String stateName;
  final double cycleOffsetMin;
  final double solMultiplier;
  final double n3Multiplier;

  const _StateCovariateTile({
    required this.stateName,
    required this.cycleOffsetMin,
    required this.solMultiplier,
    required this.n3Multiplier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offsetStr =
        cycleOffsetMin >= 0 ? '+${cycleOffsetMin.toStringAsFixed(1)}' : cycleOffsetMin.toStringAsFixed(1);
    final solStr =
        solMultiplier >= 0 ? '+${(solMultiplier * 100).round()}%' : '${(solMultiplier * 100).round()}%';
    final n3Str =
        n3Multiplier >= 1.0 ? '+${((n3Multiplier - 1.0) * 100).round()}%' : '-${((1.0 - n3Multiplier) * 100).round()}%';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stateName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Δτ: $offsetStr min  |  SOL: $solStr  |  N3: $n3Str',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stateName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                'Δτ: $offsetStr min  |  SOL: $solStr  |  N3: $n3Str',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
