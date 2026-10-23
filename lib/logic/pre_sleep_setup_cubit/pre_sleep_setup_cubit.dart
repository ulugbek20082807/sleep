import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/sleep_core_engine.dart';
import 'pre_sleep_setup_state.dart';

class PreSleepSetupCubit extends Cubit<PreSleepSetupState> {
  final SleepEngineUnifier unifier;

  PreSleepSetupCubit({
    required this.unifier,
    DateTime? initialWakeTime,
    PreSleepPhysicalState initialPhysicalState = PreSleepPhysicalState.normalBaseline,
    SleepPresetType initialPreset = SleepPresetType.basicBalancedSleep,
    bool initialAnalysisMode = false,
  }) : super(_createInitialState(
          unifier,
          initialWakeTime,
          initialPhysicalState,
          initialPreset,
          initialAnalysisMode,
        ));

  static PreSleepSetupState _createInitialState(
    SleepEngineUnifier unifier,
    DateTime? initialWakeTime,
    PreSleepPhysicalState physicalState,
    SleepPresetType preset,
    bool enableAnalysisMode,
  ) {
    final now = DateTime.now();
    DateTime wakeTime;
    if (initialWakeTime != null) {
      DateTime candidate = initialWakeTime;
      while (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      final double diffHours = candidate.difference(now).inMinutes / 60.0;
      if (diffHours >= 4.0 && diffHours <= 13.0) {
        wakeTime = candidate;
      } else {
        wakeTime = now.add(const Duration(hours: 7, minutes: 45));
      }
    } else {
      wakeTime = now.add(const Duration(hours: 7, minutes: 45));
    }

    final evaluation = unifier.previewWakeTimeHealth(
      sleepStartTime: now,
      targetWakeTime: wakeTime,
      physicalState: physicalState,
      preset: preset,
    );

    return PreSleepSetupState(
      targetWakeTime: wakeTime,
      physicalState: physicalState,
      preset: preset,
      enableAnalysisMode: enableAnalysisMode,
      evaluation: evaluation,
    );
  }

  void updateWakeTime(DateTime wakeTime) {
    final eval = unifier.previewWakeTimeHealth(
      sleepStartTime: DateTime.now(),
      targetWakeTime: wakeTime,
      physicalState: state.physicalState,
      preset: state.preset,
    );
    emit(state.copyWith(targetWakeTime: wakeTime, evaluation: eval));
  }

  void updatePhysicalState(PreSleepPhysicalState physicalState) {
    final eval = unifier.previewWakeTimeHealth(
      sleepStartTime: DateTime.now(),
      targetWakeTime: state.targetWakeTime,
      physicalState: physicalState,
      preset: state.preset,
    );
    emit(state.copyWith(physicalState: physicalState, evaluation: eval));
  }

  void updatePreset(SleepPresetType preset) {
    final eval = unifier.previewWakeTimeHealth(
      sleepStartTime: DateTime.now(),
      targetWakeTime: state.targetWakeTime,
      physicalState: state.physicalState,
      preset: preset,
    );
    emit(state.copyWith(preset: preset, evaluation: eval));
  }

  void updateAnalysisMode(bool enable) {
    emit(state.copyWith(enableAnalysisMode: enable));
  }

  void snapToIdealWakeTime() {
    final ideal = state.evaluation.nearestNaturalTroughWakeTime;
    updateWakeTime(ideal);
  }
}

