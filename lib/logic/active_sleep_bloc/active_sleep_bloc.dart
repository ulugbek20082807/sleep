import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../core/sleep_core_engine.dart';
import '../../core/sleep_engine_constants.dart';
import '../../data/models/sleep_session_record.dart';
import '../../data/repositories/sleep_history_repository.dart';
import '../../services/audio_io_service.dart';
import '../../services/sleep_foreground_service.dart';
import 'active_sleep_event.dart';
import 'active_sleep_state.dart';

class ActiveSleepBloc extends Bloc<ActiveSleepEvent, ActiveSleepState> {
  final SleepEngineUnifier unifier;
  final SleepHistoryRepository sleepHistoryRepository;
  final AudioHardwareService audioHardwareService;
  final BackgroundExecutionService backgroundService;

  Timer? _heartbeatTimer;

  // Tracking metrics across the night
  final Map<String, double> _stageMinutesSummary = {
    'wakeOnset': 0.0,
    'lightN1N2': 0.0,
    'deepN3': 0.0,
    'remDreaming': 0.0,
  };
  final List<Map<String, dynamic>> _stageTimelineSamples = [];
  bool _cycleCalibratedTonight = false;
  double? _measuredCycleDurationMin;

  ActiveSleepBloc({
    required this.unifier,
    required this.sleepHistoryRepository,
    required this.audioHardwareService,
    required this.backgroundService,
  }) : super(const ActiveSleepInitial()) {
    on<StartSleepSessionEvent>(_onStartSleepSession);
    on<SleepHeartbeatTickEvent>(_onSleepHeartbeatTick);
    on<StopSleepSessionEvent>(_onStopSleepSession);
    on<ConfirmAnalysisDataEvent>(_onConfirmAnalysisData);
  }

  Future<void> _onStartSleepSession(
    StartSleepSessionEvent event,
    Emitter<ActiveSleepState> emit,
  ) async {
    _heartbeatTimer?.cancel();
    _stageMinutesSummary['wakeOnset'] = 0.0;
    _stageMinutesSummary['lightN1N2'] = 0.0;
    _stageMinutesSummary['deepN3'] = 0.0;
    _stageMinutesSummary['remDreaming'] = 0.0;
    _stageTimelineSamples.clear();
    _cycleCalibratedTonight = false;
    _measuredCycleDurationMin = null;

    unifier.startSleepSession(
      sleepStartTime: event.sleepStartTime,
      targetWakeTime: event.targetWakeTime,
      physicalState: event.physicalState,
      preset: event.preset,
      enableAnalysisMode: event.enableAnalysisMode,
    );

    // Start background foreground service
    final wakeHour = event.targetWakeTime.hour.toString().padLeft(2, '0');
    final wakeMin = event.targetWakeTime.minute.toString().padLeft(2, '0');
    await backgroundService.startBackgroundSession(
      title: 'Sleep Perfecter Active',
      text: 'Starting session • Target Wake: $wakeHour:$wakeMin',
    );

    // Start speaker procedural audio
    await audioHardwareService.startSpeaker(
      sampleRate: SleepEngineConstants.defaultSpeakerSampleRateHz,
      onAudioRequest: (frameCount) {
        return unifier.generateNextSpeakerPcmChunk(frameCount);
      },
    );

    // If analysis mode is enabled, start microphone listener
    if (event.enableAnalysisMode) {
      await audioHardwareService.startMicrophone(
        sampleRate: SleepEngineConstants.defaultMicSampleRateHz,
        onSamples: (samples) {
          unifier.onMicrophonePcmChunkReceived(samples);
        },
      );
    }

    // Process initial tick
    final initialTick = await unifier.processEngineTick(
      currentTime: event.sleepStartTime,
      tickIntervalSeconds: 1.0,
    );

    _stageTimelineSamples.add({
      'min': 0,
      'stage': initialTick.predictionFrame.predictedStage.name,
      'dba': initialTick.mergedSpeakerRecipe.targetVolumeDba,
    });

    emit(ActiveSleepRunning(
      profileId: event.profileId,
      sleepStartTime: event.sleepStartTime,
      targetWakeTime: event.targetWakeTime,
      physicalState: event.physicalState,
      preset: event.preset,
      enableAnalysisMode: event.enableAnalysisMode,
      wakeHealthZoneAtStart: event.wakeHealthZoneAtStart,
      latestTickOutput: initialTick,
      elapsed: Duration.zero,
      cycleCalibratedTonight: false,
    ));

    // Start 1.0 second master state machine timer
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      add(SleepHeartbeatTickEvent(DateTime.now()));
    });
  }

  Future<void> _onSleepHeartbeatTick(
    SleepHeartbeatTickEvent event,
    Emitter<ActiveSleepState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ActiveSleepRunning) return;

    final tickOutput = await unifier.processEngineTick(
      currentTime: event.currentTime,
      tickIntervalSeconds: 1.0,
    );

    final Duration elapsed = event.currentTime.difference(currentState.sleepStartTime);
    final double fractionOfMinute = 1.0 / 60.0;

    // Track stage distribution
    switch (tickOutput.predictionFrame.predictedStage) {
      case PredictedSleepStage.wakeOnset:
        _stageMinutesSummary['wakeOnset'] =
            (_stageMinutesSummary['wakeOnset'] ?? 0.0) + fractionOfMinute;
        break;
      case PredictedSleepStage.n1LightTransition:
      case PredictedSleepStage.n2DescendingLight:
      case PredictedSleepStage.n2AscendingLight:
      case PredictedSleepStage.postRemFragileTrough:
      case PredictedSleepStage.preWakePriming:
        _stageMinutesSummary['lightN1N2'] =
            (_stageMinutesSummary['lightN1N2'] ?? 0.0) + fractionOfMinute;
        break;
      case PredictedSleepStage.n3SlowWaveDeep:
        _stageMinutesSummary['deepN3'] =
            (_stageMinutesSummary['deepN3'] ?? 0.0) + fractionOfMinute;
        break;
      case PredictedSleepStage.remDreaming:
        _stageMinutesSummary['remDreaming'] =
            (_stageMinutesSummary['remDreaming'] ?? 0.0) + fractionOfMinute;
        break;
    }

    // Sample hypnogram timeline every 5 minutes (300 seconds)
    if (elapsed.inSeconds > 0 && elapsed.inSeconds % 300 == 0) {
      _stageTimelineSamples.add({
        'min': (elapsed.inSeconds / 60.0).round(),
        'stage': tickOutput.predictionFrame.predictedStage.name,
        'dba': tickOutput.mergedSpeakerRecipe.targetVolumeDba,
      });
    }

    if (tickOutput.analysisFrame.cycleBoundaryRustleDetected) {
      _cycleCalibratedTonight = true;
      if (tickOutput.analysisFrame.measuredDebiasedCycleDurationMin != null) {
        _measuredCycleDurationMin =
            tickOutput.analysisFrame.measuredDebiasedCycleDurationMin;
      }
    }

    // Update notification text every 30 seconds
    if (elapsed.inSeconds % 30 == 0) {
      final wakeHour = currentState.targetWakeTime.hour.toString().padLeft(2, '0');
      final wakeMin = currentState.targetWakeTime.minute.toString().padLeft(2, '0');
      final stageName = tickOutput.predictionFrame.predictedStage.name;
      backgroundService.updateNotification(
        title: 'Sleep Perfecter Active',
        text: 'Stage: $stageName • Target Wake: $wakeHour:$wakeMin',
      );
    }

    emit(ActiveSleepRunning(
      profileId: currentState.profileId,
      sleepStartTime: currentState.sleepStartTime,
      targetWakeTime: currentState.targetWakeTime,
      physicalState: currentState.physicalState,
      preset: currentState.preset,
      enableAnalysisMode: currentState.enableAnalysisMode,
      wakeHealthZoneAtStart: currentState.wakeHealthZoneAtStart,
      latestTickOutput: tickOutput,
      elapsed: elapsed,
      cycleCalibratedTonight: _cycleCalibratedTonight,
    ));
  }

  Future<void> _onStopSleepSession(
    StopSleepSessionEvent event,
    Emitter<ActiveSleepState> emit,
  ) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final currentState = state;
    if (currentState is! ActiveSleepRunning) return;

    // Teardown audio and background execution
    await audioHardwareService.stopMicrophone();
    await audioHardwareService.stopSpeaker();
    await backgroundService.stopBackgroundSession();

    final now = DateTime.now();
    final elapsedMinutes =
        now.difference(currentState.sleepStartTime).inSeconds / 60.0;

    // Add final sample if needed
    _stageTimelineSamples.add({
      'min': elapsedMinutes.round(),
      'stage': currentState.latestTickOutput.predictionFrame.predictedStage.name,
      'dba': currentState.latestTickOutput.mergedSpeakerRecipe.targetVolumeDba,
    });

    final record = SleepSessionRecord(
      sessionId: const Uuid().v4(),
      profileId: currentState.profileId,
      sleepStartTimeIso: currentState.sleepStartTime.toIso8601String(),
      targetWakeTimeIso: currentState.targetWakeTime.toIso8601String(),
      actualEndTimeIso: now.toIso8601String(),
      totalElapsedMinutes: elapsedMinutes,
      predictedSolMinutes: currentState.latestTickOutput.predictionFrame
          .predictedSolMinutes,
      circadianShiftHours:
          currentState.latestTickOutput.predictionFrame.circadianShiftHours,
      presetUsed: currentState.preset,
      physicalStateUsed: currentState.physicalState,
      analysisModeEnabled: currentState.enableAnalysisMode,
      cycleBoundaryCalibrated: _cycleCalibratedTonight,
      measuredCycleDurationMinutes: _measuredCycleDurationMin,
      completedCyclesCount:
          currentState.latestTickOutput.predictionFrame.currentCycleIndex,
      wakeHealthZoneAtStart: currentState.wakeHealthZoneAtStart,
      stageMinutesSummary: Map<String, double>.from(_stageMinutesSummary),
      stageTimelineSamples:
          List<Map<String, dynamic>>.from(_stageTimelineSamples),
    );

    // Save record to repository
    await sleepHistoryRepository.addRecord(record);

    final int completedCycles =
        currentState.latestTickOutput.predictionFrame.currentCycleIndex;
    final bool completedAtLeastOneCycle = completedCycles >= 1 &&
        elapsedMinutes >= SleepEngineConstants.minValidCycleDurationMin;

    if (!completedAtLeastOneCycle) {
      // Short sleep session (under 1 full cycle):
      // Do not corrupt baseline profile parameters from incomplete session.
      if (currentState.enableAnalysisMode) {
        await unifier.rollbackProfileToPreSessionSnapshot();
      }
      emit(ActiveSleepCompleted(
        record,
        wasShortSession: true,
        profileWasUpdated: false,
      ));
    } else if (currentState.enableAnalysisMode && _cycleCalibratedTonight) {
      // Analysis mode was active and calibrated: prompt user confirmation before writing
      final previousProfile = unifier.profileSnapshotBeforeSession ??
          unifier.predictorModule.currentProfile;
      final proposedProfile = unifier.predictorModule.currentProfile;

      emit(ActiveSleepAwaitingConfirmation(
        record: record,
        previousProfile: previousProfile,
        proposedProfile: proposedProfile,
        measuredCycleDurationMin: _measuredCycleDurationMin,
      ));
    } else {
      emit(ActiveSleepCompleted(
        record,
        wasShortSession: false,
        profileWasUpdated: false,
      ));
    }
  }

  Future<void> _onConfirmAnalysisData(
    ConfirmAnalysisDataEvent event,
    Emitter<ActiveSleepState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ActiveSleepAwaitingConfirmation) return;

    if (event.accept) {
      await unifier.commitProfilePostSession(currentState.proposedProfile);
      emit(ActiveSleepCompleted(
        currentState.record,
        wasShortSession: false,
        profileWasUpdated: true,
      ));
    } else {
      await unifier.rollbackProfileToPreSessionSnapshot();
      emit(ActiveSleepCompleted(
        currentState.record,
        wasShortSession: false,
        profileWasUpdated: false,
      ));
    }
  }

  @override
  Future<void> close() {
    _heartbeatTimer?.cancel();
    audioHardwareService.dispose();
    backgroundService.stopBackgroundSession();
    return super.close();
  }
}
