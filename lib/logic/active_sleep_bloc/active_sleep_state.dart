import 'package:equatable/equatable.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/sleep_session_record.dart';

abstract class ActiveSleepState extends Equatable {
  const ActiveSleepState();

  @override
  List<Object?> get props => [];
}

class ActiveSleepInitial extends ActiveSleepState {
  const ActiveSleepInitial();
}

class ActiveSleepRunning extends ActiveSleepState {
  final String profileId;
  final DateTime sleepStartTime;
  final DateTime targetWakeTime;
  final PreSleepPhysicalState physicalState;
  final SleepPresetType preset;
  final bool enableAnalysisMode;
  final WakeTimeHealthZone wakeHealthZoneAtStart;

  final EngineUnifiedTickOutput latestTickOutput;
  final Duration elapsed;
  final bool cycleCalibratedTonight;

  const ActiveSleepRunning({
    required this.profileId,
    required this.sleepStartTime,
    required this.targetWakeTime,
    required this.physicalState,
    required this.preset,
    required this.enableAnalysisMode,
    required this.wakeHealthZoneAtStart,
    required this.latestTickOutput,
    required this.elapsed,
    required this.cycleCalibratedTonight,
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
        latestTickOutput,
        elapsed,
        cycleCalibratedTonight,
      ];
}

class ActiveSleepAwaitingConfirmation extends ActiveSleepState {
  final SleepSessionRecord record;
  final UserProfileModel previousProfile;
  final UserProfileModel proposedProfile;
  final double? measuredCycleDurationMin;

  const ActiveSleepAwaitingConfirmation({
    required this.record,
    required this.previousProfile,
    required this.proposedProfile,
    this.measuredCycleDurationMin,
  });

  @override
  List<Object?> get props => [
        record,
        previousProfile,
        proposedProfile,
        measuredCycleDurationMin,
      ];
}

class ActiveSleepCompleted extends ActiveSleepState {
  final SleepSessionRecord record;
  final bool wasShortSession;
  final bool profileWasUpdated;

  const ActiveSleepCompleted(
    this.record, {
    this.wasShortSession = false,
    this.profileWasUpdated = false,
  });

  @override
  List<Object?> get props => [record, wasShortSession, profileWasUpdated];
}

