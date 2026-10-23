import 'package:equatable/equatable.dart';
import '../../core/sleep_core_engine.dart';

class PreSleepSetupState extends Equatable {
  final DateTime targetWakeTime;
  final PreSleepPhysicalState physicalState;
  final SleepPresetType preset;
  final bool enableAnalysisMode;
  final WakeTimeHealthEvaluation evaluation;

  const PreSleepSetupState({
    required this.targetWakeTime,
    required this.physicalState,
    required this.preset,
    required this.enableAnalysisMode,
    required this.evaluation,
  });

  PreSleepSetupState copyWith({
    DateTime? targetWakeTime,
    PreSleepPhysicalState? physicalState,
    SleepPresetType? preset,
    bool? enableAnalysisMode,
    WakeTimeHealthEvaluation? evaluation,
  }) {
    return PreSleepSetupState(
      targetWakeTime: targetWakeTime ?? this.targetWakeTime,
      physicalState: physicalState ?? this.physicalState,
      preset: preset ?? this.preset,
      enableAnalysisMode: enableAnalysisMode ?? this.enableAnalysisMode,
      evaluation: evaluation ?? this.evaluation,
    );
  }

  @override
  List<Object?> get props => [
        targetWakeTime,
        physicalState,
        preset,
        enableAnalysisMode,
        evaluation.healthScoreNormalized,
        evaluation.healthZone,
        evaluation.matchedCycleCount,
      ];
}

