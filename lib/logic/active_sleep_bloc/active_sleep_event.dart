import 'package:equatable/equatable.dart';
import '../../core/sleep_core_engine.dart';

abstract class ActiveSleepEvent extends Equatable {
  const ActiveSleepEvent();

  @override
  List<Object?> get props => [];
}

class StartSleepSessionEvent extends ActiveSleepEvent {
  final String profileId;
  final DateTime sleepStartTime;
  final DateTime targetWakeTime;
  final PreSleepPhysicalState physicalState;
  final SleepPresetType preset;
  final bool enableAnalysisMode;
  final WakeTimeHealthZone wakeHealthZoneAtStart;

  const StartSleepSessionEvent({
    required this.profileId,
    required this.sleepStartTime,
    required this.targetWakeTime,
    required this.physicalState,
    required this.preset,
    required this.enableAnalysisMode,
    required this.wakeHealthZoneAtStart,
  });

  @override
  List<Object?> get props => [
        profileId,
        sleepStartTime,
        targetWakeTime,
        physicalState,
        preset,
        enableAnalysisMode,
        wakeHealthZoneAtStart,
      ];
}

class SleepHeartbeatTickEvent extends ActiveSleepEvent {
  final DateTime currentTime;

  const SleepHeartbeatTickEvent(this.currentTime);

  @override
  List<Object?> get props => [currentTime];
}

class StopSleepSessionEvent extends ActiveSleepEvent {
  const StopSleepSessionEvent();
}

class ConfirmAnalysisDataEvent extends ActiveSleepEvent {
  final bool accept;

  const ConfirmAnalysisDataEvent({required this.accept});

  @override
  List<Object?> get props => [accept];
}

