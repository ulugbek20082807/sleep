// FILE: lib/core/sleep_core_engine.dart
// Pure Dart Scientific Sleep Prediction, Acoustic DSP & Mic Analysis Engine.
// All tunable and scientific constants are imported from sleep_engine_constants.dart.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'sleep_engine_constants.dart';

// ============================================================================
// SECTION 1: ENUMS & SURVEY OPTIONS
// ============================================================================

enum BiologicalSex { male, female, otherOrUnspecified }

enum PreSleepPhysicalState {
  normalBaseline,
  heavyWorkout,
  heavyMealBeforeBed,
  lowExhaustion,
  highCognitiveLoad,
}

enum SleepPresetType {
  deepSleepMuscleRepair,
  deepSleepCognitiveMemory,
  basicBalancedSleep,
  wakeUpFreshAntiInertia,
}

enum PredictedSleepStage {
  wakeOnset,
  n1LightTransition,
  n2DescendingLight,
  n3SlowWaveDeep,
  n2AscendingLight,
  remDreaming,
  postRemFragileTrough,
  preWakePriming,
}

enum SurveySleepLatencyOption {
  fastUnder10Min,
  normal10To20Min,
  slow20To35Min,
  verySlowOver35Min,
  unknown,
}

enum SurveyNoiseSensitivityOption {
  lightSleeperEasilyWoken,
  averageSleeper,
  deepSleeperHardToWake,
  unknown,
}

enum SurveyCycleRhythmOption {
  shortCyclesAround80Min,
  standardCyclesAround90Min,
  longCyclesAround100PlusMin,
  unknown,
}

enum AnalysisModuleMode {
  disabled,
  passiveMonitoring,
  activeProbing,
}

enum WakeTimeHealthZone {
  redWarning, // Score < 0.45: Mid-cycle N3/REM interruption or severe sleep debt
  yellowCaution, // Score 0.45 - 0.74: Acceptable but requires high pacing stretch or 4 cycles
  greenOptimal, // Score >= 0.75: 5-6 cycles landing cleanly on a post-REM trough
}

// ============================================================================
// SECTION 2: STORAGE INTERFACE (FOR FLUTTER SHARED_PREFERENCES)
// ============================================================================

abstract class SleepProfileStorageAdapter {
  Future<String?> readString(String key);
  Future<bool> writeString(String key, String value);
}

// ============================================================================
// SECTION 3: DATA MODELS (USER PROFILE, INPUTS & OUTPUT RECIPES)
// ============================================================================

class OnboardingSurveyInput {
  final double heightCm;
  final double weightKg;
  final int ageYears;
  final BiologicalSex sex;
  final int? habitualBedtimeMinutesFromMidnight;
  final int? habitualWakeMinutesFromMidnight;
  final SurveySleepLatencyOption latencyAnswer;
  final SurveyNoiseSensitivityOption sensitivityAnswer;
  final SurveyCycleRhythmOption cycleRhythmAnswer;
  final double calibrated30dBaDigitalAmplitude;

  const OnboardingSurveyInput({
    required this.heightCm,
    required this.weightKg,
    required this.ageYears,
    this.sex = BiologicalSex.otherOrUnspecified,
    this.habitualBedtimeMinutesFromMidnight,
    this.habitualWakeMinutesFromMidnight,
    this.latencyAnswer = SurveySleepLatencyOption.unknown,
    this.sensitivityAnswer = SurveyNoiseSensitivityOption.unknown,
    this.cycleRhythmAnswer = SurveyCycleRhythmOption.unknown,
    this.calibrated30dBaDigitalAmplitude =
        SleepEngineConstants.defaultCalibrated30dBaDigitalAmp,
  });
}

class UserProfileModel {
  final double heightCm;
  final double weightKg;
  final int ageYears;
  final BiologicalSex sex;
  final double habitualBedtimeMin;
  final double habitualWakeMin;
  final double baselineCycleMinutes;
  final double baselineSolMinutes;
  final double linearCycleCurveCoeff;
  final double baseN3FractionCycle1;
  final double arousalThresholdOffsetDb;
  final double calibrated30dBaAmplitude;
  final List<double> stateCycleDurationOffsetsMin;
  final List<double> stateSolMultipliers;
  final List<double> stateN3Multipliers;
  final List<double> kalmanParameterVariances;
  final int completedAnalysisProbesCount;

  const UserProfileModel({
    required this.heightCm,
    required this.weightKg,
    required this.ageYears,
    required this.sex,
    required this.habitualBedtimeMin,
    required this.habitualWakeMin,
    required this.baselineCycleMinutes,
    required this.baselineSolMinutes,
    required this.linearCycleCurveCoeff,
    required this.baseN3FractionCycle1,
    required this.arousalThresholdOffsetDb,
    required this.calibrated30dBaAmplitude,
    required this.stateCycleDurationOffsetsMin,
    required this.stateSolMultipliers,
    required this.stateN3Multipliers,
    required this.kalmanParameterVariances,
    required this.completedAnalysisProbesCount,
  });

  double get bmi {
    final double hMeters = heightCm.clamp(
          SleepEngineConstants.minValidHeightCm,
          SleepEngineConstants.maxValidHeightCm,
        ) /
        SleepEngineConstants.cmPerMeter;
    return weightKg / (hMeters * hMeters);
  }

  factory UserProfileModel.fromOnboardingSurvey(OnboardingSurveyInput input) {
    final int clampedAge = input.ageYears.clamp(
      SleepEngineConstants.minValidAgeYears,
      SleepEngineConstants.maxValidAgeYears,
    );
    final double hMeters = input.heightCm.clamp(
          SleepEngineConstants.minValidHeightCm,
          SleepEngineConstants.maxValidHeightCm,
        ) /
        SleepEngineConstants.cmPerMeter;
    final double clampedWeight = input.weightKg.clamp(
      SleepEngineConstants.minValidWeightKg,
      SleepEngineConstants.maxValidWeightKg,
    );
    final double bmi = clampedWeight / (hMeters * hMeters);

    // 1. Sleep Onset Latency (SOL) initialization
    final double normativeSol =
        SleepEngineConstants.normativeBaseSolAtRefAgeMin +
            math.max(
                  0,
                  clampedAge - SleepEngineConstants.normativeReferenceAgeYears,
                ) *
                SleepEngineConstants.normativeSolIncreasePerYearMin;

    double initialSol;
    switch (input.latencyAnswer) {
      case SurveySleepLatencyOption.fastUnder10Min:
        initialSol = SleepEngineConstants.surveySolFastMin;
        break;
      case SurveySleepLatencyOption.normal10To20Min:
        initialSol = SleepEngineConstants.surveySolNormalMin;
        break;
      case SurveySleepLatencyOption.slow20To35Min:
        initialSol = SleepEngineConstants.surveySolSlowMin;
        break;
      case SurveySleepLatencyOption.verySlowOver35Min:
        initialSol = SleepEngineConstants.surveySolVerySlowMin;
        break;
      case SurveySleepLatencyOption.unknown:
        initialSol = normativeSol;
        break;
    }

    // 2. Cycle 1 N3 Slow-Wave fraction initialization
    final double ageDecadesOverRef = math.max(
      0.0,
      (clampedAge - SleepEngineConstants.normativeReferenceAgeYears) /
          SleepEngineConstants.yearsPerDecade,
    );
    final double baseN3 =
        (SleepEngineConstants.normativeBaseN3FractionAtRefAge -
                SleepEngineConstants.normativeN3DeclinePerDecade *
                    ageDecadesOverRef)
            .clamp(
      SleepEngineConstants.minBaseN3Fraction,
      SleepEngineConstants.maxBaseN3Fraction,
    );

    // 3. Baseline Ultradian Cycle Length & initial Kalman uncertainty
    double initialTau = SleepEngineConstants.defaultBaselineCycleMin;
    double initialTauVariance =
        SleepEngineConstants.knownCycleInitialKalmanVar;
    switch (input.cycleRhythmAnswer) {
      case SurveyCycleRhythmOption.shortCyclesAround80Min:
        initialTau = SleepEngineConstants.surveyShortCycleMin;
        break;
      case SurveyCycleRhythmOption.standardCyclesAround90Min:
        initialTau = SleepEngineConstants.defaultBaselineCycleMin;
        break;
      case SurveyCycleRhythmOption.longCyclesAround100PlusMin:
        initialTau = SleepEngineConstants.surveyLongCycleMin;
        break;
      case SurveyCycleRhythmOption.unknown:
        initialTau = SleepEngineConstants.defaultBaselineCycleMin -
            (ageDecadesOverRef *
                SleepEngineConstants.cycleDeclinePerDecadeMin);
        initialTauVariance = SleepEngineConstants.unknownCycleInitialKalmanVar;
        break;
    }

    // 4. Arousal Threshold Offset (dB) initialization
    double aatOffset = SleepEngineConstants.surveyAverageSleeperAatOffsetDb;
    switch (input.sensitivityAnswer) {
      case SurveyNoiseSensitivityOption.lightSleeperEasilyWoken:
        aatOffset = SleepEngineConstants.surveyLightSleeperAatOffsetDb;
        break;
      case SurveyNoiseSensitivityOption.averageSleeper:
        aatOffset = SleepEngineConstants.surveyAverageSleeperAatOffsetDb;
        break;
      case SurveyNoiseSensitivityOption.deepSleeperHardToWake:
        aatOffset = SleepEngineConstants.surveyDeepSleeperAatOffsetDb;
        break;
      case SurveyNoiseSensitivityOption.unknown:
        final double bmiPenalty =
            bmi > SleepEngineConstants.elevatedBmiThreshold
                ? ((bmi - SleepEngineConstants.elevatedBmiThreshold) *
                        SleepEngineConstants
                            .aatPenaltyPerBmiUnitOverThresholdDb)
                    .clamp(0.0, SleepEngineConstants.maxBmiAatPenaltyDb)
                : 0.0;
        aatOffset =
            -(ageDecadesOverRef * SleepEngineConstants.aatDeclinePerDecadeDb) -
                bmiPenalty;
        break;
    }

    // 5. Habitual Bedtime & Wake Time (in minutes from 00:00 midnight)
    const double minutesPerDay = 1440.0;
    final double bedMin = (input.habitualBedtimeMinutesFromMidnight ??
            SleepEngineConstants.defaultHabitualBedtimeMinFromMidnight)
        .toDouble();
    final double wakeMin = (input.habitualWakeMinutesFromMidnight ??
            SleepEngineConstants.defaultHabitualWakeMinFromMidnight)
        .toDouble();

    return UserProfileModel(
      heightCm: input.heightCm,
      weightKg: clampedWeight,
      ageYears: clampedAge,
      sex: input.sex,
      habitualBedtimeMin: bedMin % minutesPerDay,
      habitualWakeMin: wakeMin % minutesPerDay,
      baselineCycleMinutes: initialTau,
      baselineSolMinutes: initialSol,
      linearCycleCurveCoeff: SleepEngineConstants.defaultLinearCycleCurveCoeff,
      baseN3FractionCycle1: baseN3,
      arousalThresholdOffsetDb: aatOffset.clamp(
        SleepEngineConstants.minAatOffsetDb,
        SleepEngineConstants.maxAatOffsetDb,
      ),
      calibrated30dBaAmplitude: input.calibrated30dBaDigitalAmplitude.clamp(
        SleepEngineConstants.minCalibrated30dBaDigitalAmp,
        SleepEngineConstants.maxCalibrated30dBaDigitalAmp,
      ),
      stateCycleDurationOffsetsMin: List<double>.from(
        SleepEngineConstants.priorStateCycleDurationOffsetsMin,
      ),
      stateSolMultipliers: List<double>.from(
        SleepEngineConstants.priorStateSolMultipliers,
      ),
      stateN3Multipliers: List<double>.from(
        SleepEngineConstants.priorStateN3Multipliers,
      ),
      kalmanParameterVariances: <double>[
        initialTauVariance,
        SleepEngineConstants.defaultStateOffsetInitialKalmanVar,
        SleepEngineConstants.defaultStateOffsetInitialKalmanVar,
        SleepEngineConstants.defaultStateOffsetInitialKalmanVar,
        SleepEngineConstants.defaultStateOffsetInitialKalmanVar,
      ],
      completedAnalysisProbesCount: 0,
    );
  }

  UserProfileModel copyWith({
    double? heightCm,
    double? weightKg,
    int? ageYears,
    BiologicalSex? sex,
    double? habitualBedtimeMin,
    double? habitualWakeMin,
    double? baselineCycleMinutes,
    double? baselineSolMinutes,
    double? linearCycleCurveCoeff,
    double? baseN3FractionCycle1,
    double? arousalThresholdOffsetDb,
    double? calibrated30dBaAmplitude,
    List<double>? stateCycleDurationOffsetsMin,
    List<double>? stateSolMultipliers,
    List<double>? stateN3Multipliers,
    List<double>? kalmanParameterVariances,
    int? completedAnalysisProbesCount,
  }) {
    return UserProfileModel(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      ageYears: ageYears ?? this.ageYears,
      sex: sex ?? this.sex,
      habitualBedtimeMin: habitualBedtimeMin ?? this.habitualBedtimeMin,
      habitualWakeMin: habitualWakeMin ?? this.habitualWakeMin,
      baselineCycleMinutes: baselineCycleMinutes ?? this.baselineCycleMinutes,
      baselineSolMinutes: baselineSolMinutes ?? this.baselineSolMinutes,
      linearCycleCurveCoeff:
          linearCycleCurveCoeff ?? this.linearCycleCurveCoeff,
      baseN3FractionCycle1: baseN3FractionCycle1 ?? this.baseN3FractionCycle1,
      arousalThresholdOffsetDb:
          arousalThresholdOffsetDb ?? this.arousalThresholdOffsetDb,
      calibrated30dBaAmplitude:
          calibrated30dBaAmplitude ?? this.calibrated30dBaAmplitude,
      stateCycleDurationOffsetsMin: stateCycleDurationOffsetsMin ??
          List<double>.from(this.stateCycleDurationOffsetsMin),
      stateSolMultipliers:
          stateSolMultipliers ?? List<double>.from(this.stateSolMultipliers),
      stateN3Multipliers:
          stateN3Multipliers ?? List<double>.from(this.stateN3Multipliers),
      kalmanParameterVariances: kalmanParameterVariances ??
          List<double>.from(this.kalmanParameterVariances),
      completedAnalysisProbesCount:
          completedAnalysisProbesCount ?? this.completedAnalysisProbesCount,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'heightCm': heightCm,
        'weightKg': weightKg,
        'ageYears': ageYears,
        'sex': sex.name,
        'habitualBedtimeMin': habitualBedtimeMin,
        'habitualWakeMin': habitualWakeMin,
        'baselineCycleMinutes': baselineCycleMinutes,
        'baselineSolMinutes': baselineSolMinutes,
        'linearCycleCurveCoeff': linearCycleCurveCoeff,
        'baseN3FractionCycle1': baseN3FractionCycle1,
        'arousalThresholdOffsetDb': arousalThresholdOffsetDb,
        'calibrated30dBaAmplitude': calibrated30dBaAmplitude,
        'stateCycleDurationOffsetsMin': stateCycleDurationOffsetsMin,
        'stateSolMultipliers': stateSolMultipliers,
        'stateN3Multipliers': stateN3Multipliers,
        'kalmanParameterVariances': kalmanParameterVariances,
        'completedAnalysisProbesCount': completedAnalysisProbesCount,
      };

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      ageYears: (json['ageYears'] as num).toInt(),
      sex: BiologicalSex.values.firstWhere(
        (BiologicalSex e) => e.name == json['sex'],
        orElse: () => BiologicalSex.otherOrUnspecified,
      ),
      habitualBedtimeMin: (json['habitualBedtimeMin'] as num).toDouble(),
      habitualWakeMin: (json['habitualWakeMin'] as num).toDouble(),
      baselineCycleMinutes: (json['baselineCycleMinutes'] as num).toDouble(),
      baselineSolMinutes: (json['baselineSolMinutes'] as num).toDouble(),
      linearCycleCurveCoeff: (json['linearCycleCurveCoeff'] as num).toDouble(),
      baseN3FractionCycle1: (json['baseN3FractionCycle1'] as num).toDouble(),
      arousalThresholdOffsetDb:
          (json['arousalThresholdOffsetDb'] as num).toDouble(),
      calibrated30dBaAmplitude:
          (json['calibrated30dBaAmplitude'] as num).toDouble(),
      stateCycleDurationOffsetsMin:
          (json['stateCycleDurationOffsetsMin'] as List<dynamic>)
              .map((dynamic e) => (e as num).toDouble())
              .toList(),
      stateSolMultipliers: (json['stateSolMultipliers'] as List<dynamic>)
          .map((dynamic e) => (e as num).toDouble())
          .toList(),
      stateN3Multipliers: (json['stateN3Multipliers'] as List<dynamic>)
          .map((dynamic e) => (e as num).toDouble())
          .toList(),
      kalmanParameterVariances:
          (json['kalmanParameterVariances'] as List<dynamic>)
              .map((dynamic e) => (e as num).toDouble())
              .toList(),
      completedAnalysisProbesCount:
          (json['completedAnalysisProbesCount'] as num).toInt(),
    );
  }
}

class SoundSynthesisRecipe {
  final double targetVolumeDba;
  final double digitalLinearGain;
  final double spectralSlopeBeta;
  final double lowPassCutoffHz;
  final double highPassCutoffHz;
  final double modulationFreqHz;
  final double modulationDepthDb;
  final bool enable50msN3Pulses;
  final bool enableMorningMelodicHarmonics;
  final double melodicHarmonicMixRatio;

  const SoundSynthesisRecipe({
    required this.targetVolumeDba,
    required this.digitalLinearGain,
    required this.spectralSlopeBeta,
    required this.lowPassCutoffHz,
    this.highPassCutoffHz = SleepEngineConstants.defaultHighPassCutoffHz,
    this.modulationFreqHz = 0.0,
    this.modulationDepthDb = 0.0,
    this.enable50msN3Pulses = false,
    this.enableMorningMelodicHarmonics = false,
    this.melodicHarmonicMixRatio = 0.0,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'targetVolumeDba': targetVolumeDba,
        'digitalLinearGain': digitalLinearGain,
        'spectralSlopeBeta': spectralSlopeBeta,
        'lowPassCutoffHz': lowPassCutoffHz,
        'highPassCutoffHz': highPassCutoffHz,
        'modulationFreqHz': modulationFreqHz,
        'modulationDepthDb': modulationDepthDb,
        'enable50msN3Pulses': enable50msN3Pulses,
        'enableMorningMelodicHarmonics': enableMorningMelodicHarmonics,
        'melodicHarmonicMixRatio': melodicHarmonicMixRatio,
      };
}

class PredictedSleepStateFrame {
  final double elapsedMinutesSinceSessionStart;
  final double effectiveMinutesSinceSleepOnset;
  final double predictedSolMinutes;
  final double circadianShiftHours;
  final int currentCycleIndex;
  final int optimalTotalCyclesForWakeWindow;
  final double cycleProgressFraction;
  final double currentCyclePredictedDurationMin;
  final double currentCycleStartElapsedMin;
  final double currentCyclePredictedEndElapsedMin;
  final double minutesUntilCurrentCycleBoundary;
  final double stagePacingStretchFactor;
  final PredictedSleepStage predictedStage;
  final double estimatedArousalThresholdDba;
  final SoundSynthesisRecipe baseSoundRecipe;

  const PredictedSleepStateFrame({
    required this.elapsedMinutesSinceSessionStart,
    required this.effectiveMinutesSinceSleepOnset,
    required this.predictedSolMinutes,
    required this.circadianShiftHours,
    required this.currentCycleIndex,
    required this.optimalTotalCyclesForWakeWindow,
    required this.cycleProgressFraction,
    required this.currentCyclePredictedDurationMin,
    required this.currentCycleStartElapsedMin,
    required this.currentCyclePredictedEndElapsedMin,
    required this.minutesUntilCurrentCycleBoundary,
    required this.stagePacingStretchFactor,
    required this.predictedStage,
    required this.estimatedArousalThresholdDba,
    required this.baseSoundRecipe,
  });
}

class AnalysisModuleEvaluationResult {
  final AnalysisModuleMode currentMode;
  final bool shouldSwitchToActiveProbeFunction;
  final bool shouldRevertToPassiveFunction;
  final bool cycleBoundaryRustleDetected;
  final SoundSynthesisRecipe? probeOverlaySoundRecipe;
  final double currentHighFreqMicDba;
  final double rollingHighFreqFloorDba;
  final double? measuredDebiasedCycleDurationMin;
  final double? phaseShiftOffsetAddedMin;
  final UserProfileModel? updatedUserProfile;

  const AnalysisModuleEvaluationResult({
    required this.currentMode,
    required this.shouldSwitchToActiveProbeFunction,
    required this.shouldRevertToPassiveFunction,
    required this.cycleBoundaryRustleDetected,
    this.probeOverlaySoundRecipe,
    required this.currentHighFreqMicDba,
    required this.rollingHighFreqFloorDba,
    this.measuredDebiasedCycleDurationMin,
    this.phaseShiftOffsetAddedMin,
    this.updatedUserProfile,
  });
}

class EngineUnifiedTickOutput {
  final PredictedSleepStateFrame predictionFrame;
  final AnalysisModuleEvaluationResult analysisFrame;
  final SoundSynthesisRecipe mergedSpeakerRecipe;
  final bool profileWasUpdatedThisTick;
  final UserProfileModel activeProfile;

  const EngineUnifiedTickOutput({
    required this.predictionFrame,
    required this.analysisFrame,
    required this.mergedSpeakerRecipe,
    required this.profileWasUpdatedThisTick,
    required this.activeProfile,
  });
}

class WakeTimeHealthEvaluation {
  /// Normalized health & alignment score in [0.0, 1.0] to drive the UI progress bar.
  final double healthScoreNormalized;

  /// Color zone (Red, Yellow, Green) for the UI progress bar and status badge.
  final WakeTimeHealthZone healthZone;

  /// Optimal number of complete sleep cycles (K*) for this wake window.
  final int matchedCycleCount;

  /// Predicted Sleep Onset Latency (in minutes) tonight before Cycle 1 starts.
  final double predictedSolMinutes;

  /// Total net time spent asleep (in minutes) after subtracting SOL.
  final double netSleepDurationMinutes;

  /// Required stage-pacing multiplier (e.g. 1.03 = +3% stretch).
  final double requiredPacingFactor;

  /// Unpaced gap (in minutes) between natural K* cycle completion and targetWakeTime.
  final double rawPhaseMismatchMinutes;

  /// Nearest ideal wake-up DateTime if the user wants a 100% natural 0%-stretch trough.
  final DateTime nearestNaturalTroughWakeTime;

  /// Concise, user-facing scientific explanation for the UI card.
  final String statusHeadline;
  final String statusSubtitle;

  const WakeTimeHealthEvaluation({
    required this.healthScoreNormalized,
    required this.healthZone,
    required this.matchedCycleCount,
    required this.predictedSolMinutes,
    required this.netSleepDurationMinutes,
    required this.requiredPacingFactor,
    required this.rawPhaseMismatchMinutes,
    required this.nearestNaturalTroughWakeTime,
    required this.statusHeadline,
    required this.statusSubtitle,
  });
}

// ============================================================================
// SECTION 4: MODULE 1 — SLEEP ACOUSTIC PREDICTOR MODULE
// ============================================================================

class SleepAcousticPredictorModule {
  UserProfileModel _profile;

  SleepAcousticPredictorModule({required UserProfileModel initialProfile})
      : _profile = initialProfile;

  UserProfileModel get currentProfile => _profile;

  void updateProfile(UserProfileModel newProfile) {
    _profile = newProfile;
  }

  /// Converts target dBA to linear digital gain [0.0, 1.0] using the physics
  /// amplitude ratio formula: A = A_ref * 10^((L - L_ref) / 20).
  double dbaToDigitalAmplitude(double targetDba) {
    final double clampedDba = targetDba.clamp(
      SleepEngineConstants.minSpeakerOutputDba,
      SleepEngineConstants.maxSpeakerOutputDba,
    );
    final double amp = _profile.calibrated30dBaAmplitude *
        math.pow(
          10.0,
          (clampedDba - SleepEngineConstants.referenceCalibrationDba) / 20.0,
        );
    return amp.clamp(0.0, 1.0);
  }

  /// Computes signed circadian misalignment in hours [-12.0, +12.0].
  double computeCircadianShiftHours(DateTime sleepStartTime) {
    const double minutesPerHour = 60.0;
    const double minutesPerDay = 1440.0;
    const double halfDayMinutes = 720.0;

    final double startMin = sleepStartTime.hour * minutesPerHour +
        sleepStartTime.minute +
        (sleepStartTime.second / minutesPerHour);
    double diffMin = startMin - _profile.habitualBedtimeMin;
    while (diffMin <= -halfDayMinutes) {
      diffMin += minutesPerDay;
    }
    while (diffMin > halfDayMinutes) {
      diffMin -= minutesPerDay;
    }
    return diffMin / minutesPerHour;
  }

  double predictSleepOnsetLatencyMinutes({
    required DateTime sleepStartTime,
    required PreSleepPhysicalState physicalState,
  }) {
    final double stateMult = _getStateMultiplier(
      physicalState,
      _profile.stateSolMultipliers,
    );
    final double deltaCircHours = computeCircadianShiftHours(sleepStartTime);

    // 1. Wake Maintenance Zone (WMZ) Gaussian penalty when sleeping earlier
    double wmzPenaltyMin = 0.0;
    if (deltaCircHours < SleepEngineConstants.wmzUpperBoundShiftHours &&
        deltaCircHours >= SleepEngineConstants.wmzLowerBoundShiftHours) {
      final double z =
          (deltaCircHours - SleepEngineConstants.wmzPeakCenterShiftHours) /
              SleepEngineConstants.wmzGaussianWidthHours;
      wmzPenaltyMin =
          SleepEngineConstants.wmzMaxSolPenaltyMin * math.exp(-0.5 * z * z);
    }

    // 2. Elevated Process S compression when sleeping later than usual
    double lateSleepCompressionFactor = 1.0;
    if (deltaCircHours > SleepEngineConstants.lateBedtimeThresholdHours) {
      lateSleepCompressionFactor = math
          .exp(
            -SleepEngineConstants.lateBedtimeSolDecayRatePerHour *
                (deltaCircHours -
                    SleepEngineConstants.lateBedtimeThresholdHours),
          )
          .clamp(
            SleepEngineConstants.minLateBedtimeSolCompressionFactor,
            1.0,
          );
    }

    final double rawSol = (_profile.baselineSolMinutes *
            (1.0 + stateMult) *
            lateSleepCompressionFactor) +
        wmzPenaltyMin;
    return rawSol.clamp(
      SleepEngineConstants.minPredictedSolMin,
      SleepEngineConstants.maxPredictedSolMin,
    );
  }

  double predictNaturalCycleDurationMinutes({
    required int cycleIndex,
    required PreSleepPhysicalState physicalState,
  }) {
    final double stateOffset = _getStateMultiplier(
      physicalState,
      _profile.stateCycleDurationOffsetsMin,
    );
    final double cycleDecay = math.exp(
      -SleepEngineConstants.stateEffectCycleDecayRate * (cycleIndex - 1),
    );
    final double curveTerm = _profile.linearCycleCurveCoeff *
        (cycleIndex - SleepEngineConstants.cycleCurveCenterIndex);

    final double duration =
        _profile.baselineCycleMinutes + curveTerm + (stateOffset * cycleDecay);
    return duration.clamp(
      SleepEngineConstants.minValidCycleDurationMin,
      SleepEngineConstants.maxValidCycleDurationMin,
    );
  }

  PredictedSleepStateFrame evaluateSleepAndProposeSound({
    required DateTime currentTime,
    required DateTime sleepStartTime,
    required DateTime targetWakeTime,
    required PreSleepPhysicalState physicalState,
    required SleepPresetType preset,
    required bool enforceMicrophoneFrequencySplit,
    double cumulativePhaseShiftMinutes = 0.0,
    Map<int, double> measuredCycleDurationsTonight = const <int, double>{},
  }) {
    const double msPerMinute = 60000.0;
    final double elapsedMin =
        currentTime.difference(sleepStartTime).inMilliseconds / msPerMinute;
    final double totalAvailableWindowMin =
        targetWakeTime.difference(sleepStartTime).inMilliseconds / msPerMinute;

    final double deltaCircHours = computeCircadianShiftHours(sleepStartTime);
    final double predictedSol = predictSleepOnsetLatencyMinutes(
      sleepStartTime: sleepStartTime,
      physicalState: physicalState,
    );

    final double effectiveSleepMin =
        elapsedMin - predictedSol - cumulativePhaseShiftMinutes;

    final double netSleepWindowMin = math.max(
      SleepEngineConstants.minNetSleepWindowMin,
      totalAvailableWindowMin - predictedSol - cumulativePhaseShiftMinutes,
    );

    int bestK = SleepEngineConstants.defaultCandidateCycles;
    double minAbsError = double.infinity;
    double bestNaturalSum =
        SleepEngineConstants.defaultCandidateCycles *
            SleepEngineConstants.defaultBaselineCycleMin;

    for (int kCand = SleepEngineConstants.minCandidateCycles;
        kCand <= SleepEngineConstants.maxCandidateCycles;
        kCand++) {
      double sumMin = 0.0;
      for (int c = 1; c <= kCand; c++) {
        sumMin += measuredCycleDurationsTonight[c] ??
            predictNaturalCycleDurationMinutes(
              cycleIndex: c,
              physicalState: physicalState,
            );
      }
      final double err = (netSleepWindowMin - sumMin).abs();
      if (err < minAbsError) {
        minAbsError = err;
        bestK = kCand;
        bestNaturalSum = sumMin;
      }
    }

    double pacingFactor = (netSleepWindowMin / bestNaturalSum).clamp(
      SleepEngineConstants.minStagePacingFactor,
      SleepEngineConstants.maxStagePacingFactor,
    );
    if (preset == SleepPresetType.deepSleepMuscleRepair) {
      pacingFactor = pacingFactor.clamp(
        SleepEngineConstants.muscleRepairMinPacingFactor,
        SleepEngineConstants.maxStagePacingFactor,
      );
    }

    if (effectiveSleepMin < 0.0) {
      final SoundSynthesisRecipe onsetRecipe = _buildOnsetSoundRecipe(
        elapsedMin: elapsedMin,
        predictedSol: predictedSol,
        deltaCircHours: deltaCircHours,
        physicalState: physicalState,
        preset: preset,
        enforceMicSplit: enforceMicrophoneFrequencySplit,
      );

      final double cycle1Dur = predictNaturalCycleDurationMinutes(
            cycleIndex: 1,
            physicalState: physicalState,
          ) *
          pacingFactor;

      return PredictedSleepStateFrame(
        elapsedMinutesSinceSessionStart: elapsedMin,
        effectiveMinutesSinceSleepOnset: effectiveSleepMin,
        predictedSolMinutes: predictedSol,
        circadianShiftHours: deltaCircHours,
        currentCycleIndex: 0,
        optimalTotalCyclesForWakeWindow: bestK,
        cycleProgressFraction: (elapsedMin / predictedSol).clamp(0.0, 1.0),
        currentCyclePredictedDurationMin: cycle1Dur,
        currentCycleStartElapsedMin: predictedSol,
        currentCyclePredictedEndElapsedMin: predictedSol + cycle1Dur,
        minutesUntilCurrentCycleBoundary:
            (predictedSol + cycle1Dur) - elapsedMin,
        stagePacingStretchFactor: pacingFactor,
        predictedStage: PredictedSleepStage.wakeOnset,
        estimatedArousalThresholdDba:
            SleepEngineConstants.aatWakeOnsetDba +
                _profile.arousalThresholdOffsetDb,
        baseSoundRecipe: onsetRecipe,
      );
    }

    double cursorMin = 0.0;
    int activeCycle = 1;
    double activeCycleDur = SleepEngineConstants.defaultBaselineCycleMin;

    for (int c = 1;
        c <= SleepEngineConstants.maxSessionCycleSearchLimit;
        c++) {
      final double cDur = measuredCycleDurationsTonight[c] ??
          (predictNaturalCycleDurationMinutes(
                cycleIndex: c,
                physicalState: physicalState,
              ) *
              pacingFactor);
      if (effectiveSleepMin < cursorMin + cDur ||
          c == SleepEngineConstants.maxSessionCycleSearchLimit) {
        activeCycle = c;
        activeCycleDur = cDur;
        break;
      }
      cursorMin += cDur;
    }

    final double minIntoCycle =
        (effectiveSleepMin - cursorMin).clamp(0.0, activeCycleDur);
    final double cycleProgress =
        (minIntoCycle / activeCycleDur).clamp(0.0, 1.0);

    final double cycleStartElapsed =
        predictedSol + cumulativePhaseShiftMinutes + cursorMin;
    final double cycleEndElapsed = cycleStartElapsed + activeCycleDur;
    final double minUntilBoundary = cycleEndElapsed - elapsedMin;

    final double stateN3Mult = _getStateMultiplier(
      physicalState,
      _profile.stateN3Multipliers,
    );
    final double lateSleepN3Boost =
        deltaCircHours > SleepEngineConstants.lateBedtimeThresholdHours
            ? (SleepEngineConstants.lateSleepN3BoostPerHour *
                    (deltaCircHours -
                        SleepEngineConstants.lateBedtimeThresholdHours))
                .clamp(0.0, SleepEngineConstants.maxLateSleepN3BoostFraction)
            : 0.0;

    final double n3Share = ((_profile.baseN3FractionCycle1 + lateSleepN3Boost) *
            math.exp(
              -SleepEngineConstants.n3ExponentialDecayRatePerCycle *
                  (activeCycle - 1),
            ) *
            (1.0 + stateN3Mult))
        .clamp(
      SleepEngineConstants.minCycleN3Fraction,
      SleepEngineConstants.maxCycleN3Fraction,
    );

    final double n3EndFrac =
        SleepEngineConstants.descendingLightSleepFraction + n3Share;
    final double ascEndFrac =
        n3EndFrac + SleepEngineConstants.ascendingLightSleepFraction;
    final double remEndFrac =
        (1.0 - SleepEngineConstants.postRemFragileTroughFraction).clamp(
      ascEndFrac + SleepEngineConstants.minRemFractionAfterAscending,
      SleepEngineConstants.maxRemEndFractionOfCycle,
    );

    final double minutesBeforeTargetWake =
        targetWakeTime.difference(currentTime).inMilliseconds / msPerMinute;

    PredictedSleepStage currentStage;
    if (minutesBeforeTargetWake <=
            SleepEngineConstants.preWakePrimingStageWindowMin &&
        minutesBeforeTargetWake >=
            SleepEngineConstants.morningWakePostTargetGraceMin &&
        preset == SleepPresetType.wakeUpFreshAntiInertia) {
      currentStage = PredictedSleepStage.preWakePriming;
    } else if (cycleProgress < SleepEngineConstants.n1EntryFractionOfCycle) {
      currentStage = PredictedSleepStage.n1LightTransition;
    } else if (cycleProgress <
        SleepEngineConstants.descendingLightSleepFraction) {
      currentStage = PredictedSleepStage.n2DescendingLight;
    } else if (cycleProgress < n3EndFrac) {
      currentStage = PredictedSleepStage.n3SlowWaveDeep;
    } else if (cycleProgress < ascEndFrac) {
      currentStage = PredictedSleepStage.n2AscendingLight;
    } else if (cycleProgress < remEndFrac) {
      currentStage = PredictedSleepStage.remDreaming;
    } else {
      currentStage = PredictedSleepStage.postRemFragileTrough;
    }

    final double estimatedAatDba = _estimateStageArousalThresholdDba(
      stage: currentStage,
      physicalState: physicalState,
    );

    final SoundSynthesisRecipe cycleRecipe = _buildCycleSoundRecipe(
      stage: currentStage,
      activeCycle: activeCycle,
      cycleProgress: cycleProgress,
      minutesBeforeTargetWake: minutesBeforeTargetWake,
      pacingFactor: pacingFactor,
      physicalState: physicalState,
      preset: preset,
      enforceMicSplit: enforceMicrophoneFrequencySplit,
    );

    return PredictedSleepStateFrame(
      elapsedMinutesSinceSessionStart: elapsedMin,
      effectiveMinutesSinceSleepOnset: effectiveSleepMin,
      predictedSolMinutes: predictedSol,
      circadianShiftHours: deltaCircHours,
      currentCycleIndex: activeCycle,
      optimalTotalCyclesForWakeWindow: bestK,
      cycleProgressFraction: cycleProgress,
      currentCyclePredictedDurationMin: activeCycleDur,
      currentCycleStartElapsedMin: cycleStartElapsed,
      currentCyclePredictedEndElapsedMin: cycleEndElapsed,
      minutesUntilCurrentCycleBoundary: minUntilBoundary,
      stagePacingStretchFactor: pacingFactor,
      predictedStage: currentStage,
      estimatedArousalThresholdDba: estimatedAatDba,
      baseSoundRecipe: cycleRecipe,
    );
  }

  double _getStateMultiplier(
    PreSleepPhysicalState state,
    List<double> fourElementVector,
  ) {
    if (state == PreSleepPhysicalState.normalBaseline) {
      return 0.0;
    }
    return fourElementVector[state.index - 1];
  }

  double _estimateStageArousalThresholdDba({
    required PredictedSleepStage stage,
    required PreSleepPhysicalState physicalState,
  }) {
    double stateAatShift = 0.0;
    if (physicalState == PreSleepPhysicalState.lowExhaustion) {
      stateAatShift = SleepEngineConstants.aatLowExhaustionShiftDb;
    } else if (physicalState == PreSleepPhysicalState.heavyWorkout) {
      stateAatShift = SleepEngineConstants.aatHeavyWorkoutShiftDb;
    } else if (physicalState == PreSleepPhysicalState.heavyMealBeforeBed) {
      stateAatShift = SleepEngineConstants.aatHeavyMealShiftDb;
    }

    double baseStageDba;
    switch (stage) {
      case PredictedSleepStage.wakeOnset:
        baseStageDba = SleepEngineConstants.aatWakeOnsetDba;
        break;
      case PredictedSleepStage.postRemFragileTrough:
      case PredictedSleepStage.n1LightTransition:
      case PredictedSleepStage.preWakePriming:
        baseStageDba = SleepEngineConstants.aatLightTroughN1Dba;
        break;
      case PredictedSleepStage.n2DescendingLight:
      case PredictedSleepStage.n2AscendingLight:
        baseStageDba = SleepEngineConstants.aatN2LightSleepDba;
        break;
      case PredictedSleepStage.remDreaming:
        baseStageDba = SleepEngineConstants.aatRemSleepDba;
        break;
      case PredictedSleepStage.n3SlowWaveDeep:
        baseStageDba = SleepEngineConstants.aatN3DeepSleepDba;
        break;
    }
    return (baseStageDba + _profile.arousalThresholdOffsetDb + stateAatShift)
        .clamp(
      SleepEngineConstants.minEstimatedAatDba,
      SleepEngineConstants.maxEstimatedAatDba,
    );
  }

  SoundSynthesisRecipe _buildOnsetSoundRecipe({
    required double elapsedMin,
    required double predictedSol,
    required double deltaCircHours,
    required PreSleepPhysicalState physicalState,
    required SleepPresetType preset,
    required bool enforceMicSplit,
  }) {
    final double progress = (elapsedMin / predictedSol).clamp(0.0, 1.0);
    final bool inWmz =
        deltaCircHours < SleepEngineConstants.wmzAcousticBoostThresholdHours &&
            deltaCircHours >= SleepEngineConstants.wmzLowerBoundShiftHours;
    final double wmzBoostDb =
        inWmz ? SleepEngineConstants.onsetWmzBoostDb : 0.0;

    final double startDba = SleepEngineConstants.onsetBaseStartDba + wmzBoostDb;
    final double endDba = SleepEngineConstants.onsetTargetEndDba;
    final double currentDba = startDba - (startDba - endDba) * progress;

    final double maxCutoff = enforceMicSplit
        ? SleepEngineConstants.speakerMicSplitMaxLowPassHz
        : SleepEngineConstants.onsetUnconstrainedMaxLowPassHz;
    final double minCutoff = SleepEngineConstants.onsetMinLowPassHz;
    final double cutoffHz =
        maxCutoff * math.pow(minCutoff / maxCutoff, progress);

    final double breathFreqHz = SleepEngineConstants.onsetStartBreathFreqHz -
        (SleepEngineConstants.onsetBreathFreqDropHz * progress);

    return SoundSynthesisRecipe(
      targetVolumeDba: currentDba,
      digitalLinearGain: dbaToDigitalAmplitude(currentDba),
      spectralSlopeBeta: inWmz
          ? SleepEngineConstants.onsetSlopeBetaWmz
          : SleepEngineConstants.onsetSlopeBetaNormal,
      lowPassCutoffHz: cutoffHz,
      highPassCutoffHz: SleepEngineConstants.defaultHighPassCutoffHz,
      modulationFreqHz: breathFreqHz,
      modulationDepthDb:
          SleepEngineConstants.onsetInitialModulationDepthDb *
              (1.0 - 0.5 * progress),
      enable50msN3Pulses: false,
      enableMorningMelodicHarmonics: false,
      melodicHarmonicMixRatio: 0.0,
    );
  }

  SoundSynthesisRecipe _buildCycleSoundRecipe({
    required PredictedSleepStage stage,
    required int activeCycle,
    required double cycleProgress,
    required double minutesBeforeTargetWake,
    required double pacingFactor,
    required PreSleepPhysicalState physicalState,
    required SleepPresetType preset,
    required bool enforceMicSplit,
  }) {
    final double maxAllowedLpHz = enforceMicSplit
        ? SleepEngineConstants.speakerMicSplitMaxLowPassHz
        : SleepEngineConstants.cycleUnconstrainedMaxLowPassHz;

    // 1. Morning Pre-Wake Priming & Awakening Ramp Window
    if (minutesBeforeTargetWake <=
            SleepEngineConstants.morningWakeWindowBeforeTargetMin &&
        minutesBeforeTargetWake >=
            SleepEngineConstants.morningWakePostTargetGraceMin) {
      final double wakeProgress =
          ((SleepEngineConstants.morningWakeWindowBeforeTargetMin -
                      minutesBeforeTargetWake) /
                  SleepEngineConstants.morningWakeWindowBeforeTargetMin)
              .clamp(0.0, 1.0);
      final double targetDba = SleepEngineConstants.morningWakeStartDba +
          (SleepEngineConstants.morningWakeAddedDbaSpan *
              math.pow(
                wakeProgress,
                SleepEngineConstants.morningWakeCurveExponent,
              ));
      final double cutoffHz = (SleepEngineConstants.morningWakeBaseLowPassHz +
              SleepEngineConstants.morningWakeAddedLowPassHz * wakeProgress)
          .clamp(
        SleepEngineConstants.morningWakeMinLowPassClampHz,
        maxAllowedLpHz,
      );
      final bool useMelodic = minutesBeforeTargetWake <=
          SleepEngineConstants.morningMelodicCrossfadeWindowMin;
      final double melodicMix = useMelodic
          ? ((SleepEngineConstants.morningMelodicCrossfadeWindowMin -
                      minutesBeforeTargetWake) /
                  SleepEngineConstants.morningMelodicCrossfadeWindowMin)
              .clamp(0.0, 1.0)
          : 0.0;

      return SoundSynthesisRecipe(
        targetVolumeDba: targetDba,
        digitalLinearGain: dbaToDigitalAmplitude(targetDba),
        spectralSlopeBeta: SleepEngineConstants.morningWakeSlopeBeta,
        lowPassCutoffHz: cutoffHz,
        highPassCutoffHz: SleepEngineConstants.morningWakeBaseHighPassHz +
            (SleepEngineConstants.morningWakeAddedHighPassHz * wakeProgress),
        modulationFreqHz:
            useMelodic ? SleepEngineConstants.morningMelodicPulseFreqHz : 0.0,
        modulationDepthDb: useMelodic
            ? SleepEngineConstants.morningMelodicModulationDepthDb
            : 0.0,
        enable50msN3Pulses: false,
        enableMorningMelodicHarmonics: useMelodic,
        melodicHarmonicMixRatio: melodicMix,
      );
    }

    // 2. Nocturnal Masking Shield Adjustment
    final double shieldOffsetDb =
        (physicalState == PreSleepPhysicalState.heavyMealBeforeBed ||
                _profile.bmi > SleepEngineConstants.elevatedBmiThreshold)
            ? SleepEngineConstants.heavyMealOrHighBmiMaskingBoostDb
            : 0.0;

    // 3. Stage-Specific Synthesis
    switch (stage) {
      case PredictedSleepStage.n3SlowWaveDeep:
        final bool pulseActive =
            (activeCycle <= SleepEngineConstants.maxCycleIndexForN3Pulses) &&
                (preset == SleepPresetType.deepSleepMuscleRepair ||
                    preset == SleepPresetType.deepSleepCognitiveMemory);
        final double n3Dba = (pulseActive
                ? SleepEngineConstants.n3PulseActiveDba
                : SleepEngineConstants.n3PassiveShieldDba) +
            (shieldOffsetDb * 0.5);
        return SoundSynthesisRecipe(
          targetVolumeDba: n3Dba,
          digitalLinearGain: dbaToDigitalAmplitude(n3Dba),
          spectralSlopeBeta: preset == SleepPresetType.deepSleepMuscleRepair
              ? SleepEngineConstants.n3SlopeBetaMuscleRepair
              : SleepEngineConstants.n3SlopeBetaCognitive,
          lowPassCutoffHz: SleepEngineConstants.n3LowPassCutoffHz.clamp(
            SleepEngineConstants.minSafeLowPassCutoffHz,
            maxAllowedLpHz,
          ),
          highPassCutoffHz: SleepEngineConstants.n3HighPassCutoffHz,
          modulationFreqHz: pulseActive
              ? SleepEngineConstants.n3SlowOscillationFreqHz
              : 0.0,
          modulationDepthDb: pulseActive
              ? SleepEngineConstants.n3PulseModulationDepthDb
              : 0.0,
          enable50msN3Pulses: pulseActive,
        );

      case PredictedSleepStage.remDreaming:
        final double remDba =
            SleepEngineConstants.remShieldBaseDba + shieldOffsetDb;
        return SoundSynthesisRecipe(
          targetVolumeDba: remDba,
          digitalLinearGain: dbaToDigitalAmplitude(remDba),
          spectralSlopeBeta: SleepEngineConstants.remSlopeBeta,
          lowPassCutoffHz: SleepEngineConstants.remLowPassCutoffHz.clamp(
            SleepEngineConstants.minSafeLowPassCutoffHz,
            maxAllowedLpHz,
          ),
          highPassCutoffHz: SleepEngineConstants.defaultHighPassCutoffHz,
          modulationFreqHz: 0.0,
          modulationDepthDb: 0.0,
          enable50msN3Pulses: false,
        );

      case PredictedSleepStage.n2AscendingLight:
        final bool shortenCycle =
            pacingFactor < SleepEngineConstants.shortenCyclePacingThreshold;
        final double ascDba =
            SleepEngineConstants.ascLightBaseDba + shieldOffsetDb;
        return SoundSynthesisRecipe(
          targetVolumeDba: ascDba,
          digitalLinearGain: dbaToDigitalAmplitude(ascDba),
          spectralSlopeBeta: shortenCycle
              ? SleepEngineConstants.ascShortenSlopeBeta
              : SleepEngineConstants.ascNormalSlopeBeta,
          lowPassCutoffHz: (shortenCycle
                  ? SleepEngineConstants.ascShortenLowPassHz
                  : SleepEngineConstants.ascNormalLowPassHz)
              .clamp(
            SleepEngineConstants.minSafeLowPassCutoffHz,
            maxAllowedLpHz,
          ),
          highPassCutoffHz: shortenCycle
              ? SleepEngineConstants.ascShortenHighPassHz
              : SleepEngineConstants.ascNormalHighPassHz,
          modulationFreqHz: 0.0,
          modulationDepthDb: 0.0,
          enable50msN3Pulses: false,
        );

      case PredictedSleepStage.postRemFragileTrough:
      case PredictedSleepStage.n1LightTransition:
      case PredictedSleepStage.n2DescendingLight:
      case PredictedSleepStage.preWakePriming:
      case PredictedSleepStage.wakeOnset:
        final double baseDba =
            SleepEngineConstants.defaultCycleMaskingDba + shieldOffsetDb;
        return SoundSynthesisRecipe(
          targetVolumeDba: baseDba,
          digitalLinearGain: dbaToDigitalAmplitude(baseDba),
          spectralSlopeBeta: SleepEngineConstants.defaultCycleSlopeBeta,
          lowPassCutoffHz: SleepEngineConstants.defaultCycleLowPassHz.clamp(
            SleepEngineConstants.minSafeLowPassCutoffHz,
            maxAllowedLpHz,
          ),
          highPassCutoffHz: SleepEngineConstants.defaultHighPassCutoffHz,
          modulationFreqHz: 0.0,
          modulationDepthDb: 0.0,
          enable50msN3Pulses: false,
        );
    }
  }

  /// Evaluates any candidate [targetWakeTime] on the Pre-Sleep Setup screen
  /// and returns a [WakeTimeHealthEvaluation] (0.0-1.0 score + Red/Yellow/Green zone)
  /// to drive the auto-updating wake-up health indicator bar.
  WakeTimeHealthEvaluation evaluateWakeTimeHealthPreview({
    required DateTime sleepStartTime,
    required DateTime targetWakeTime,
    required PreSleepPhysicalState physicalState,
    required SleepPresetType preset,
  }) {
    const double msPerMinute = 60000.0;
    DateTime normalizedWake = targetWakeTime;
    while (!normalizedWake.isAfter(sleepStartTime)) {
      normalizedWake = normalizedWake.add(const Duration(days: 1));
    }

    final double totalWindowMin =
        normalizedWake.difference(sleepStartTime).inMilliseconds / msPerMinute;
    final double predictedSol = predictSleepOnsetLatencyMinutes(
      sleepStartTime: sleepStartTime,
      physicalState: physicalState,
    );
    final double netSleepMin = math.max(0.0, totalWindowMin - predictedSol);

    // Find the closest cycle count K* in [1..8]
    int bestK = 1;
    double minAbsError = double.infinity;
    double bestNaturalSumMin = SleepEngineConstants.defaultBaselineCycleMin;

    for (int kCand = 1;
        kCand <= SleepEngineConstants.maxCandidateCycles + 1;
        kCand++) {
      double sumMin = 0.0;
      for (int c = 1; c <= kCand; c++) {
        sumMin += predictNaturalCycleDurationMinutes(
          cycleIndex: c,
          physicalState: physicalState,
        );
      }
      final double err = (netSleepMin - sumMin).abs();
      if (err < minAbsError) {
        minAbsError = err;
        bestK = kCand;
        bestNaturalSumMin = sumMin;
      }
    }

    final double rawMismatchMin = netSleepMin - bestNaturalSumMin;
    final double mismatchFraction =
        bestNaturalSumMin > 0.0 ? (rawMismatchMin.abs() / bestNaturalSumMin) : 1.0;
    final double requiredPacing =
        bestNaturalSumMin > 0.0 ? (netSleepMin / bestNaturalSumMin) : 1.0;

    // 1. Score Sleep Duration Adequacy (Cycle Count K*)
    double durationScore;
    if (bestK >= SleepEngineConstants.minOptimalCyclesGreen &&
        bestK <= SleepEngineConstants.maxOptimalCyclesGreen) {
      durationScore = SleepEngineConstants.optimalCycleDurationScore;
    } else if (bestK == SleepEngineConstants.minAcceptableCyclesYellow ||
        bestK == SleepEngineConstants.maxCandidateCycles) {
      durationScore = SleepEngineConstants.fourCycleDurationScore;
    } else if (bestK == SleepEngineConstants.minCandidateCycles) {
      durationScore = SleepEngineConstants.threeCycleDurationScore;
    } else if (bestK > SleepEngineConstants.maxCandidateCycles) {
      // Extended sleep window (>7 cycles): valid extended rest
      durationScore = 0.65;
    } else {
      durationScore = SleepEngineConstants.underThreeCycleDurationScore;
    }

    // 2. Score Ultradian Phase Alignment (Can acoustic pacing bridge the gap?)
    double alignmentScore;
    if (mismatchFraction <=
        SleepEngineConstants.effortlessPacingMismatchFraction) {
      alignmentScore = 1.0 -
          (0.15 *
              (mismatchFraction /
                  SleepEngineConstants.effortlessPacingMismatchFraction));
    } else if (mismatchFraction <=
        SleepEngineConstants.maxSafePacingMismatchFraction) {
      final double span = SleepEngineConstants.maxSafePacingMismatchFraction -
          SleepEngineConstants.effortlessPacingMismatchFraction;
      final double pos = mismatchFraction -
          SleepEngineConstants.effortlessPacingMismatchFraction;
      alignmentScore = 0.85 - (0.35 * (pos / span));
    } else {
      final double excess = mismatchFraction -
          SleepEngineConstants.maxSafePacingMismatchFraction;
      alignmentScore = (0.50 *
              math.exp(
                -excess /
                    (SleepEngineConstants.severePhaseMismatchFraction -
                        SleepEngineConstants.maxSafePacingMismatchFraction),
              ))
          .clamp(0.05, 0.50);
    }

    double combinedScore =
        (SleepEngineConstants.durationScoreWeight * durationScore) +
            (SleepEngineConstants.alignmentScoreWeight * alignmentScore);

    // Hard cap into Red zone if total sleep is < 3 cycles or phase mismatch > 14%
    if (bestK < SleepEngineConstants.minCandidateCycles ||
        netSleepMin < SleepEngineConstants.minNetSleepWindowMin) {
      combinedScore = math.min(
        combinedScore,
        SleepEngineConstants.wakeHealthYellowThreshold - 0.10,
      );
    }

    final double finalScore = combinedScore.clamp(0.0, 1.0);
    WakeTimeHealthZone zone;
    if (finalScore >= SleepEngineConstants.wakeHealthGreenThreshold) {
      zone = WakeTimeHealthZone.greenOptimal;
    } else if (finalScore >= SleepEngineConstants.wakeHealthYellowThreshold) {
      zone = WakeTimeHealthZone.yellowCaution;
    } else {
      zone = WakeTimeHealthZone.redWarning;
    }

    // Determine the optimal target cycle count for the recommended natural trough
    int targetIdealK;
    if (netSleepMin < 3.5 * SleepEngineConstants.defaultBaselineCycleMin) {
      targetIdealK = 4;
    } else if (netSleepMin <= 5.5 * SleepEngineConstants.defaultBaselineCycleMin) {
      targetIdealK = 5;
    } else {
      targetIdealK = 6;
    }

    double idealNaturalSumMin = 0.0;
    for (int c = 1; c <= targetIdealK; c++) {
      idealNaturalSumMin += predictNaturalCycleDurationMinutes(
        cycleIndex: c,
        physicalState: physicalState,
      );
    }

    final DateTime idealWakeTime = sleepStartTime.add(
      Duration(
        milliseconds: ((predictedSol + idealNaturalSumMin) * msPerMinute).round(),
      ),
    );

    final double deltaCircHours = computeCircadianShiftHours(sleepStartTime);
    final bool isDaytimeOrNightOwl = deltaCircHours.abs() > 3.0 ||
        (sleepStartTime.hour >= 5 && sleepStartTime.hour <= 15);

    String headline;
    String subtitle;
    if (zone == WakeTimeHealthZone.greenOptimal) {
      if (isDaytimeOrNightOwl) {
        headline = 'Optimal Wake Alignment ($bestK Cycles • Flexible Schedule)';
        subtitle =
            'Harmonized for your daytime schedule and night-owl rhythm. Acoustic pacing (${((requiredPacing - 1.0) * 100.0).toStringAsFixed(1)}%) will land you cleanly in a light-sleep trough.';
      } else {
        headline = 'Optimal Wake Alignment ($bestK Full Cycles)';
        subtitle =
            'Acoustic pacing (${((requiredPacing - 1.0) * 100.0).toStringAsFixed(1)}%) will land you cleanly in a natural light-sleep trough.';
      }
    } else if (zone == WakeTimeHealthZone.yellowCaution) {
      if (isDaytimeOrNightOwl) {
        headline = 'Daytime Window ($bestK Cycles)';
        subtitle =
            'Pacing is active. Consider aiming for $targetIdealK cycles near ${idealWakeTime.hour.toString().padLeft(2, '0')}:${idealWakeTime.minute.toString().padLeft(2, '0')} for peak cognitive recovery.';
      } else if (bestK < SleepEngineConstants.minOptimalCyclesGreen) {
        headline = 'Short Sleep Window ($bestK Cycles)';
        subtitle =
            'Cycle boundary aligns well, but $bestK cycles provides reduced late-night REM recovery.';
      } else {
        headline = 'Near Acoustic Pacing Limit ($bestK Cycles)';
        subtitle =
            'Requires ${rawMismatchMin.abs().round()} min cycle adjustment. Ideal natural trough is around ${idealWakeTime.hour.toString().padLeft(2, '0')}:${idealWakeTime.minute.toString().padLeft(2, '0')}.';
      }
    } else {
      if (isDaytimeOrNightOwl) {
        headline = 'High Sleep Inertia Risk ($bestK Cycles)';
        subtitle =
            'Target time cuts into deeper sleep. For a refreshing night-owl wake-up, aim near ${idealWakeTime.hour.toString().padLeft(2, '0')}:${idealWakeTime.minute.toString().padLeft(2, '0')} ($targetIdealK cycles).';
      } else {
        headline = 'High Sleep Inertia Risk ($bestK Cycles)';
        subtitle =
            'Target time cuts into deep or REM sleep or is too short. Consider waking near ${idealWakeTime.hour.toString().padLeft(2, '0')}:${idealWakeTime.minute.toString().padLeft(2, '0')}.';
      }
    }

    return WakeTimeHealthEvaluation(
      healthScoreNormalized: finalScore,
      healthZone: zone,
      matchedCycleCount: bestK,
      predictedSolMinutes: predictedSol,
      netSleepDurationMinutes: netSleepMin,
      requiredPacingFactor: requiredPacing.clamp(
        SleepEngineConstants.minStagePacingFactor,
        SleepEngineConstants.maxStagePacingFactor,
      ),
      rawPhaseMismatchMinutes: rawMismatchMin,
      nearestNaturalTroughWakeTime: idealWakeTime,
      statusHeadline: headline,
      statusSubtitle: subtitle,
    );
  }
}

// ============================================================================
// SECTION 5: MODULE 2 — ANALYSIS MODE & MIC RUSTLE DETECTOR MODULE
// ============================================================================

class _HighPassBiquadFilter2500Hz {
  late double _b0, _b1, _b2, _a1, _a2;
  double _x1 = 0.0, _x2 = 0.0, _y1 = 0.0, _y2 = 0.0;

  _HighPassBiquadFilter2500Hz({required int sampleRateHz}) {
    const double cutoffHz = SleepEngineConstants.micHighPassCutoffHz;
    const double q = SleepEngineConstants.butterworthQFactor;
    final double omega = 2.0 * math.pi * cutoffHz / sampleRateHz;
    final double sinW = math.sin(omega);
    final double cosW = math.cos(omega);
    final double alpha = sinW / (2.0 * q);

    final double a0 = 1.0 + alpha;
    _b0 = ((1.0 + cosW) / 2.0) / a0;
    _b1 = -(1.0 + cosW) / a0;
    _b2 = ((1.0 + cosW) / 2.0) / a0;
    _a1 = (-2.0 * cosW) / a0;
    _a2 = (1.0 - alpha) / a0;
  }

  double processFrameAndComputeRms(List<double> pcmSamples) {
    if (pcmSamples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (int i = 0; i < pcmSamples.length; i++) {
      final double x0 = pcmSamples[i];
      final double y0 =
          _b0 * x0 + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
      _x2 = _x1;
      _x1 = x0;
      _y2 = _y1;
      _y1 = y0;
      sumSquares += y0 * y0;
    }
    return math.sqrt(sumSquares / pcmSamples.length);
  }
}

class AnalysisProbeModule {
  bool isEnabled;
  final int micSampleRateHz;
  late final _HighPassBiquadFilter2500Hz _highPassFilter;

  AnalysisModuleMode _mode = AnalysisModuleMode.passiveMonitoring;

  double _rollingHighFreqFloorDba =
      SleepEngineConstants.initialHighFreqNoiseFloorDba;
  double _latestHighFreqMicDba =
      SleepEngineConstants.initialHighFreqNoiseFloorDba;
  double _maxHighFreqMicDbaSinceLastTick =
      SleepEngineConstants.initialHighFreqNoiseFloorDba;

  int? _currentlyProbingCycleIndex;
  double? _activeProbeStartElapsedMin;
  double _currentProbeTargetDba = SleepEngineConstants.probeStartVolumeDba;
  double _lastVolumeStepTimestampMin = 0.0;

  double _continuousRustleSeconds = 0.0;
  double _peakRustleSnrDb = 0.0;

  final Set<int> _probedCyclesTonight = <int>{};
  int _targetCycleToProbeTonight = 1;

  AnalysisProbeModule({
    required this.isEnabled,
    this.micSampleRateHz = SleepEngineConstants.defaultMicSampleRateHz,
    int completedProbesCount = 0,
  }) {
    _highPassFilter = _HighPassBiquadFilter2500Hz(sampleRateHz: micSampleRateHz);
    _targetCycleToProbeTonight =
        (completedProbesCount % SleepEngineConstants.numRotatableProbeCycles) +
            1;
    _mode = isEnabled
        ? AnalysisModuleMode.passiveMonitoring
        : AnalysisModuleMode.disabled;
  }

  AnalysisModuleMode get currentMode => _mode;

  void ingestMicrophonePcmChunk(
    List<double> rawMonoPcmChunk, {
    required double calibrated30dBaAmplitude,
  }) {
    if (!isEnabled || rawMonoPcmChunk.isEmpty) return;

    final double highFreqRms =
        _highPassFilter.processFrameAndComputeRms(rawMonoPcmChunk);
    final double safeRms = math.max(
      SleepEngineConstants.minRmsNumericalEpsilon,
      highFreqRms,
    );
    final double refAmp = math.max(
      SleepEngineConstants.minRefAmpNumericalEpsilon,
      calibrated30dBaAmplitude,
    );

    final double instantDba = (SleepEngineConstants.referenceCalibrationDba +
            20.0 * (math.log(safeRms / refAmp) / math.ln10))
        .clamp(
      SleepEngineConstants.minTrackedMicDba,
      SleepEngineConstants.maxTrackedMicDba,
    );
    _latestHighFreqMicDba = instantDba;
    if (instantDba > _maxHighFreqMicDbaSinceLastTick) {
      _maxHighFreqMicDbaSinceLastTick = instantDba;
    }

    final bool isTransientSpike = (instantDba - _rollingHighFreqFloorDba) >=
        SleepEngineConstants.rustleDetectionSnrThresholdDb;

    if (instantDba < _rollingHighFreqFloorDba) {
      const double aDown =
          SleepEngineConstants.floorFastDownwardSmoothingAlpha;
      _rollingHighFreqFloorDba =
          aDown * _rollingHighFreqFloorDba + (1.0 - aDown) * instantDba;
    } else if (_continuousRustleSeconds == 0.0 && !isTransientSpike) {
      const double aUp = SleepEngineConstants.floorSlowUpwardSmoothingAlpha;
      _rollingHighFreqFloorDba =
          aUp * _rollingHighFreqFloorDba + (1.0 - aUp) * instantDba;
    }
  }

  /// Module 2 — Function 1: Default Passive Monitoring Routine
  AnalysisModuleEvaluationResult evaluatePassiveMonitoringStep({
    required PredictedSleepStateFrame currentSleepFrame,
    required UserProfileModel currentProfile,
    required PreSleepPhysicalState physicalState,
  }) {
    if (!isEnabled) {
      return AnalysisModuleEvaluationResult(
        currentMode: AnalysisModuleMode.disabled,
        shouldSwitchToActiveProbeFunction: false,
        shouldRevertToPassiveFunction: false,
        cycleBoundaryRustleDetected: false,
        currentHighFreqMicDba: _latestHighFreqMicDba,
        rollingHighFreqFloorDba: _rollingHighFreqFloorDba,
      );
    }

    final int cycleIdx = currentSleepFrame.currentCycleIndex;
    final double minToBoundary =
        currentSleepFrame.minutesUntilCurrentCycleBoundary;

    final bool eligibleCycle = (cycleIdx == _targetCycleToProbeTonight) &&
        !_probedCyclesTonight.contains(cycleIdx) &&
        (_probedCyclesTonight.isEmpty);

    if (eligibleCycle &&
        minToBoundary <=
            SleepEngineConstants.probeEntryMinutesBeforeBoundary &&
        minToBoundary >= SleepEngineConstants.probeEntryMinutesAfterBoundary) {
      _mode = AnalysisModuleMode.activeProbing;
      _currentlyProbingCycleIndex = cycleIdx;
      _activeProbeStartElapsedMin =
          currentSleepFrame.elapsedMinutesSinceSessionStart;
      _currentProbeTargetDba = SleepEngineConstants.probeStartVolumeDba;
      _lastVolumeStepTimestampMin =
          currentSleepFrame.elapsedMinutesSinceSessionStart;
      _continuousRustleSeconds = 0.0;
      _peakRustleSnrDb = 0.0;

      return AnalysisModuleEvaluationResult(
        currentMode: _mode,
        shouldSwitchToActiveProbeFunction: true,
        shouldRevertToPassiveFunction: false,
        cycleBoundaryRustleDetected: false,
        currentHighFreqMicDba: _latestHighFreqMicDba,
        rollingHighFreqFloorDba: _rollingHighFreqFloorDba,
      );
    }

    return AnalysisModuleEvaluationResult(
      currentMode: AnalysisModuleMode.passiveMonitoring,
      shouldSwitchToActiveProbeFunction: false,
      shouldRevertToPassiveFunction: false,
      cycleBoundaryRustleDetected: false,
      currentHighFreqMicDba: _latestHighFreqMicDba,
      rollingHighFreqFloorDba: _rollingHighFreqFloorDba,
    );
  }

  /// Module 2 — Function 2: Active Acoustic Probe & Rustle Detection Routine
  AnalysisModuleEvaluationResult executeActiveProbeStep({
    required PredictedSleepStateFrame currentSleepFrame,
    required UserProfileModel currentProfile,
    required PreSleepPhysicalState physicalState,
    required double tickIntervalSeconds,
  }) {
    final double elapsedMin = currentSleepFrame.elapsedMinutesSinceSessionStart;
    final int cycleIdx =
        _currentlyProbingCycleIndex ?? currentSleepFrame.currentCycleIndex;

    final double maxSafeCeilingDba =
        (physicalState == PreSleepPhysicalState.lowExhaustion
                ? SleepEngineConstants.probeLowExhaustionCeilingDba
                : SleepEngineConstants.probeNormalCeilingDba) +
            (currentProfile.arousalThresholdOffsetDb *
                SleepEngineConstants.probePersonalAatOffsetScaling);
    final double clampedCeilingDba = maxSafeCeilingDba.clamp(
      SleepEngineConstants.probeMinAllowedCeilingDba,
      SleepEngineConstants.probeMaxAllowedCeilingDba,
    );

    if (elapsedMin - _lastVolumeStepTimestampMin >=
        SleepEngineConstants.probeStepIntervalMin) {
      _currentProbeTargetDba =
          (_currentProbeTargetDba + SleepEngineConstants.probeStepSizeDb).clamp(
        SleepEngineConstants.probeStartVolumeDba,
        clampedCeilingDba,
      );
      _lastVolumeStepTimestampMin = elapsedMin;
    }

    final double peakMicDbaThisTick = _maxHighFreqMicDbaSinceLastTick;
    _maxHighFreqMicDbaSinceLastTick = _latestHighFreqMicDba;
    final double snrDb = peakMicDbaThisTick - _rollingHighFreqFloorDba;
    final bool isAboveRustleThreshold =
        snrDb >= SleepEngineConstants.rustleDetectionSnrThresholdDb;

    bool validRustleConfirmed = false;
    if (isAboveRustleThreshold) {
      _continuousRustleSeconds += tickIntervalSeconds;
      if (snrDb > _peakRustleSnrDb) {
        _peakRustleSnrDb = snrDb;
      }
    } else {
      if (_continuousRustleSeconds >=
              SleepEngineConstants.minValidRustleDurationSec &&
          _continuousRustleSeconds <=
              SleepEngineConstants.maxValidRustleDurationSec) {
        validRustleConfirmed = true;
      }
      _continuousRustleSeconds = 0.0;
    }

    if (_continuousRustleSeconds >=
            SleepEngineConstants.immediateConfirmRustleMinSec &&
        _continuousRustleSeconds <=
            SleepEngineConstants.immediateConfirmRustleMaxSec &&
        snrDb >= SleepEngineConstants.rustleImmediateConfirmSnrDb) {
      validRustleConfirmed = true;
      _continuousRustleSeconds = 0.0;
    }

    if (validRustleConfirmed) {
      _probedCyclesTonight.add(cycleIdx);
      _mode = AnalysisModuleMode.passiveMonitoring;

      final double normProbeLevel = ((_currentProbeTargetDba -
                  SleepEngineConstants.probeStartVolumeDba) /
              (clampedCeilingDba - SleepEngineConstants.probeStartVolumeDba))
          .clamp(0.0, 1.0);
      final double reactionBiasMin =
          SleepEngineConstants.minReactionDebiasMin +
              (SleepEngineConstants.addedReactionDebiasSpanMin * normProbeLevel);

      final double trueBoundaryElapsedMin = elapsedMin - reactionBiasMin;
      final double debiasedDurationMin = (trueBoundaryElapsedMin -
              currentSleepFrame.currentCycleStartElapsedMin)
          .clamp(
        SleepEngineConstants.minValidCycleDurationMin,
        SleepEngineConstants.maxValidCycleDurationMin,
      );

      final UserProfileModel updatedProfile = _performKalmanProfileUpdate(
        profile: currentProfile,
        physicalState: physicalState,
        cycleIndex: cycleIdx,
        observedCycleDurationMin: debiasedDurationMin,
      );

      return AnalysisModuleEvaluationResult(
        currentMode: AnalysisModuleMode.passiveMonitoring,
        shouldSwitchToActiveProbeFunction: false,
        shouldRevertToPassiveFunction: true,
        cycleBoundaryRustleDetected: true,
        probeOverlaySoundRecipe: null,
        currentHighFreqMicDba: _latestHighFreqMicDba,
        rollingHighFreqFloorDba: _rollingHighFreqFloorDba,
        measuredDebiasedCycleDurationMin: debiasedDurationMin,
        phaseShiftOffsetAddedMin:
            SleepEngineConstants.postProbeMicroArousalPhaseShiftMin,
        updatedUserProfile: updatedProfile,
      );
    }

    final double probeElapsedMin =
        elapsedMin - (_activeProbeStartElapsedMin ?? elapsedMin);
    if (probeElapsedMin >= SleepEngineConstants.probeMaxWindowDurationMin ||
        currentSleepFrame.minutesUntilCurrentCycleBoundary <
            SleepEngineConstants.probeTimeoutMinutesAfterBoundary) {
      _probedCyclesTonight.add(cycleIdx);
      _mode = AnalysisModuleMode.passiveMonitoring;

      return AnalysisModuleEvaluationResult(
        currentMode: AnalysisModuleMode.passiveMonitoring,
        shouldSwitchToActiveProbeFunction: false,
        shouldRevertToPassiveFunction: true,
        cycleBoundaryRustleDetected: false,
        probeOverlaySoundRecipe: null,
        currentHighFreqMicDba: _latestHighFreqMicDba,
        rollingHighFreqFloorDba: _rollingHighFreqFloorDba,
      );
    }

    final double digitalAmp = currentProfile.calibrated30dBaAmplitude *
        math.pow(
          10.0,
          (_currentProbeTargetDba -
                  SleepEngineConstants.referenceCalibrationDba) /
              20.0,
        );

    final SoundSynthesisRecipe activeProbeRecipe = SoundSynthesisRecipe(
      targetVolumeDba: _currentProbeTargetDba,
      digitalLinearGain: digitalAmp.clamp(0.0, 1.0),
      spectralSlopeBeta: SleepEngineConstants.probeSoundSlopeBeta,
      lowPassCutoffHz: SleepEngineConstants.probeSoundLowPassHz,
      highPassCutoffHz: SleepEngineConstants.probeSoundHighPassHz,
      modulationFreqHz: SleepEngineConstants.probeSoundSwellFreqHz,
      modulationDepthDb: SleepEngineConstants.probeSoundSwellDepthDb,
      enable50msN3Pulses: false,
    );

    return AnalysisModuleEvaluationResult(
      currentMode: AnalysisModuleMode.activeProbing,
      shouldSwitchToActiveProbeFunction: false,
      shouldRevertToPassiveFunction: false,
      cycleBoundaryRustleDetected: false,
      probeOverlaySoundRecipe: activeProbeRecipe,
      currentHighFreqMicDba: _latestHighFreqMicDba,
      rollingHighFreqFloorDba: _rollingHighFreqFloorDba,
    );
  }

  UserProfileModel _performKalmanProfileUpdate({
    required UserProfileModel profile,
    required PreSleepPhysicalState physicalState,
    required int cycleIndex,
    required double observedCycleDurationMin,
  }) {
    const double observationNoiseVar =
        SleepEngineConstants.kalmanObservationNoiseVariance;
    const double processDriftVar =
        SleepEngineConstants.kalmanProcessDriftVariance;

    final List<double> variances =
        List<double>.from(profile.kalmanParameterVariances);
    final List<double> stateOffsets =
        List<double>.from(profile.stateCycleDurationOffsetsMin);

    final double curveTerm = profile.linearCycleCurveCoeff *
        (cycleIndex - SleepEngineConstants.cycleCurveCenterIndex);
    final double cycleDecay = math.exp(
      -SleepEngineConstants.stateEffectCycleDecayRate * (cycleIndex - 1),
    );

    if (physicalState == PreSleepPhysicalState.normalBaseline) {
      final double pred = profile.baselineCycleMinutes + curveTerm;
      final double innovationError = observedCycleDurationMin - pred;

      final double p0 = variances[0] + processDriftVar;
      final double kalmanGain = p0 / (p0 + observationNoiseVar);

      final double newTau =
          (profile.baselineCycleMinutes + kalmanGain * innovationError).clamp(
        SleepEngineConstants.minLearnedBaselineCycleMin,
        SleepEngineConstants.maxLearnedBaselineCycleMin,
      );
      variances[0] = ((1.0 - kalmanGain) * p0).clamp(
        SleepEngineConstants.minKalmanTauVariance,
        SleepEngineConstants.maxKalmanTauVariance,
      );

      return profile.copyWith(
        baselineCycleMinutes: newTau,
        kalmanParameterVariances: variances,
        completedAnalysisProbesCount: profile.completedAnalysisProbesCount + 1,
      );
    } else {
      final int stateIdx = physicalState.index - 1;
      final double currentOffset = stateOffsets[stateIdx];
      final double pred = profile.baselineCycleMinutes +
          curveTerm +
          (currentOffset * cycleDecay);
      final double innovationError = observedCycleDurationMin - pred;

      final double pTau = variances[0] + processDriftVar;
      final double pState = variances[stateIdx + 1] + processDriftVar;

      final double denom = pTau +
          (cycleDecay * cycleDecay * pState) +
          observationNoiseVar;

      final double kTau = pTau / denom;
      final double kState = (pState * cycleDecay) / denom;

      final double newTau =
          (profile.baselineCycleMinutes + kTau * innovationError).clamp(
        SleepEngineConstants.minLearnedBaselineCycleMin,
        SleepEngineConstants.maxLearnedBaselineCycleMin,
      );
      final double newStateOffset =
          (currentOffset + kState * innovationError).clamp(
        SleepEngineConstants.minLearnedStateOffsetMin,
        SleepEngineConstants.maxLearnedStateOffsetMin,
      );

      variances[0] = ((1.0 - kTau) * pTau).clamp(
        SleepEngineConstants.minKalmanTauVariance,
        SleepEngineConstants.maxKalmanTauVariance,
      );
      variances[stateIdx + 1] =
          ((1.0 - kState * cycleDecay) * pState).clamp(
        SleepEngineConstants.minKalmanStateVariance,
        SleepEngineConstants.maxKalmanStateVariance,
      );
      stateOffsets[stateIdx] = newStateOffset;

      return profile.copyWith(
        baselineCycleMinutes: newTau,
        stateCycleDurationOffsetsMin: stateOffsets,
        kalmanParameterVariances: variances,
        completedAnalysisProbesCount: profile.completedAnalysisProbesCount + 1,
      );
    }
  }
}

// ============================================================================
// SECTION 6: REAL-TIME PROCEDURAL PCM SYNTHESIZER (VOSS-MCCARTNEY + SVF FILTER)
// ============================================================================

class ProceduralSleepAudioSynthesizer {
  final int sampleRateHz;
  final math.Random _rng = math.Random();

  double _b0 = 0.0,
      _b1 = 0.0,
      _b2 = 0.0,
      _b3 = 0.0,
      _b4 = 0.0,
      _b5 = 0.0,
      _b6 = 0.0;
  double _brownState = 0.0;
  double _ic1eq = 0.0, _ic2eq = 0.0;
  double _hpX1 = 0.0, _hpY1 = 0.0;
  double _modPhase = 0.0;
  int _sampleCounter = 0;

  ProceduralSleepAudioSynthesizer({
    this.sampleRateHz = SleepEngineConstants.defaultSpeakerSampleRateHz,
  });

  Float32List synthesizePcmBuffer(
    int frameCount,
    SoundSynthesisRecipe recipe,
  ) {
    final Float32List out = Float32List(frameCount);

    final double cutoff = recipe.lowPassCutoffHz.clamp(
      SleepEngineConstants.minSynthesizerLowPassHz,
      sampleRateHz * SleepEngineConstants.nyquistSafetyFraction,
    );
    final double g = math.tan(math.pi * cutoff / sampleRateHz);
    const double k = SleepEngineConstants.svfButterworthDampingK;
    final double a1 = 1.0 / (1.0 + g * (g + k));
    final double a2 = g * a1;
    final double a3 = g * a2;

    final double hpCutoff = recipe.highPassCutoffHz.clamp(
      20.0,
      cutoff * SleepEngineConstants.nyquistSafetyFraction,
    );
    final double hpRc = 1.0 / (2.0 * math.pi * hpCutoff);
    final double hpDt = 1.0 / sampleRateHz;
    final double hpAlpha = hpRc / (hpRc + hpDt);

    final double brownMix = ((recipe.spectralSlopeBeta -
                SleepEngineConstants.minSpectralSlopeBeta) /
            SleepEngineConstants.spectralSlopeBetaSpan)
        .clamp(0.0, 1.0);
    final double pinkMix = 1.0 - brownMix;

    final int pulsePeriodSamples =
        (sampleRateHz / SleepEngineConstants.n3SlowOscillationFreqHz).round();
    final int pulseWidthSamples =
        (SleepEngineConstants.n3PulseDurationSeconds * sampleRateHz).round();
    final int rampSamples =
        (SleepEngineConstants.n3PulseCosineRampSeconds * sampleRateHz).round();

    for (int i = 0; i < frameCount; i++) {
      _sampleCounter++;
      final double white = (_rng.nextDouble() * 2.0) - 1.0;

      // 1. Paul Kellet 1/f Pink Noise filter
      _b0 = SleepEngineConstants.kelletP0Pole * _b0 +
          white * SleepEngineConstants.kelletP0Gain;
      _b1 = SleepEngineConstants.kelletP1Pole * _b1 +
          white * SleepEngineConstants.kelletP1Gain;
      _b2 = SleepEngineConstants.kelletP2Pole * _b2 +
          white * SleepEngineConstants.kelletP2Gain;
      _b3 = SleepEngineConstants.kelletP3Pole * _b3 +
          white * SleepEngineConstants.kelletP3Gain;
      _b4 = SleepEngineConstants.kelletP4Pole * _b4 +
          white * SleepEngineConstants.kelletP4Gain;
      _b5 = SleepEngineConstants.kelletP5Pole * _b5 -
          white * SleepEngineConstants.kelletP5Gain;
      final double pink = (_b0 +
              _b1 +
              _b2 +
              _b3 +
              _b4 +
              _b5 +
              _b6 +
              white * SleepEngineConstants.kelletWhiteFeedforwardGain) *
          SleepEngineConstants.kelletOutputNormalizationGain;
      _b6 = white * SleepEngineConstants.kelletState6WhiteGain;

      // 2. Leaky integrator for 1/f^2 Brown Noise
      _brownState = ((_brownState +
                  (SleepEngineConstants.brownLeakyStepGain * white)) /
              SleepEngineConstants.brownLeakyDenominator)
          .clamp(-1.0, 1.0);
      final double rawNoise = (pinkMix * pink) +
          (brownMix *
              _brownState *
              SleepEngineConstants.brownOutputBoostGain);

      // 3. Cytomic State-Variable Low-Pass + One-Pole High-Pass Filter
      final double v3 = rawNoise - _ic2eq;
      final double v1 = a1 * _ic1eq + a2 * v3;
      final double v2 = _ic2eq + a2 * _ic1eq + a3 * v3;
      _ic1eq = 2.0 * v1 - _ic1eq;
      _ic2eq = 2.0 * v2 - _ic2eq;

      final double hpOut = hpAlpha * (_hpY1 + v2 - _hpX1);
      _hpX1 = v2;
      _hpY1 = hpOut;
      double filteredSample = hpOut;

      // 3b. Mix in morning major-chord harmonics if in awakening window
      if (recipe.enableMorningMelodicHarmonics &&
          recipe.melodicHarmonicMixRatio > 0.0) {
        final double tSec = _sampleCounter / sampleRateHz;
        final double chord = (math.sin(2.0 *
                    math.pi *
                    SleepEngineConstants.morningHarmonicFreq1Hz *
                    tSec) +
                math.sin(2.0 *
                    math.pi *
                    SleepEngineConstants.morningHarmonicFreq2Hz *
                    tSec) +
                math.sin(2.0 *
                    math.pi *
                    SleepEngineConstants.morningHarmonicFreq3Hz *
                    tSec)) *
            SleepEngineConstants.morningHarmonicBaseAmp;
        final double mix = recipe.melodicHarmonicMixRatio.clamp(0.0, 1.0);
        filteredSample = ((1.0 - mix) * filteredSample) + (mix * chord);
      }

      // 4. Slow breathing modulation or 50 ms N3 slow-oscillation pulses
      double envMultiplier = 1.0;
      if (recipe.enable50msN3Pulses) {
        final int posInCycle = _sampleCounter % pulsePeriodSamples;
        if (posInCycle < pulseWidthSamples) {
          double window = 1.0;
          if (posInCycle < rampSamples) {
            window = 0.5 *
                (1.0 - math.cos(math.pi * posInCycle / rampSamples));
          } else if (posInCycle > pulseWidthSamples - rampSamples) {
            final int rem = pulseWidthSamples - posInCycle;
            window = 0.5 * (1.0 - math.cos(math.pi * rem / rampSamples));
          }
          envMultiplier = 1.0 +
              (SleepEngineConstants.n3PulsePeakBoostMultiplier * window);
        } else {
          envMultiplier = SleepEngineConstants.n3InterPulseFloorGainRatio;
        }
      } else if (recipe.modulationFreqHz > 0.0 &&
          recipe.modulationDepthDb > 0.0) {
        _modPhase += (2.0 * math.pi * recipe.modulationFreqHz) / sampleRateHz;
        if (_modPhase > 2.0 * math.pi) _modPhase -= 2.0 * math.pi;
        final double dbOffset =
            (recipe.modulationDepthDb * 0.5) * math.sin(_modPhase);
        envMultiplier = math.pow(10.0, dbOffset / 20.0).toDouble();
      }

      out[i] = (filteredSample * recipe.digitalLinearGain * envMultiplier)
          .clamp(
        -SleepEngineConstants.pcmHardLimiterCeiling,
        SleepEngineConstants.pcmHardLimiterCeiling,
      );
    }
    return out;
  }
}

// ============================================================================
// SECTION 7: MODULE 3 — THE UNIFIER ORCHESTRATOR ENGINE
// ============================================================================

class SleepEngineUnifier {
  final SleepProfileStorageAdapter storageAdapter;
  late SleepAcousticPredictorModule predictorModule;
  late AnalysisProbeModule analysisModule;
  final ProceduralSleepAudioSynthesizer audioSynthesizer;

  String _activeProfileStorageKey = SleepEngineConstants.profileStorageKey;

  DateTime? _sessionStartTime;
  DateTime? _targetWakeTime;
  PreSleepPhysicalState _physicalState = PreSleepPhysicalState.normalBaseline;
  SleepPresetType _activePreset = SleepPresetType.basicBalancedSleep;

  UserProfileModel? _profileSnapshotBeforeSession;
  UserProfileModel? get profileSnapshotBeforeSession => _profileSnapshotBeforeSession;

  bool _routeToModule2ActiveProbeFunction = false;
  double _cumulativePhaseShiftMinutes = 0.0;
  final Map<int, double> _measuredCyclesTonight = <int, double>{};
  SoundSynthesisRecipe? _latestMergedRecipe;

  SleepEngineUnifier({
    required this.storageAdapter,
    int sampleRateHz = SleepEngineConstants.defaultSpeakerSampleRateHz,
  }) : audioSynthesizer =
            ProceduralSleepAudioSynthesizer(sampleRateHz: sampleRateHz);

  Future<UserProfileModel> initializeAndLoadProfile({
    required OnboardingSurveyInput fallbackSurvey,
    required bool enableAnalysisModeTonight,
    int micSampleRateHz = SleepEngineConstants.defaultMicSampleRateHz,
    String? customProfileId,
  }) async {
    _activeProfileStorageKey = (customProfileId != null && customProfileId.isNotEmpty)
        ? '${SleepEngineConstants.profileStorageKey}_$customProfileId'
        : SleepEngineConstants.profileStorageKey;

    UserProfileModel loadedProfile;
    final String? rawJson = await storageAdapter.readString(
      _activeProfileStorageKey,
    );

    if (rawJson != null && rawJson.isNotEmpty) {
      loadedProfile = UserProfileModel.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );
    } else {
      loadedProfile = UserProfileModel.fromOnboardingSurvey(fallbackSurvey);
      await saveProfileToStorage(loadedProfile);
    }

    predictorModule =
        SleepAcousticPredictorModule(initialProfile: loadedProfile);
    analysisModule = AnalysisProbeModule(
      isEnabled: enableAnalysisModeTonight,
      micSampleRateHz: micSampleRateHz,
      completedProbesCount: loadedProfile.completedAnalysisProbesCount,
    );
    _routeToModule2ActiveProbeFunction = false;
    return loadedProfile;
  }

  Future<void> saveProfileToStorage(UserProfileModel profile) async {
    await storageAdapter.writeString(
      _activeProfileStorageKey,
      jsonEncode(profile.toJson()),
    );
  }

  /// Reverts the active profile and storage back to the pre-session snapshot
  /// if a sleep session was terminated prematurely or rejected by user confirmation.
  Future<void> rollbackProfileToPreSessionSnapshot() async {
    if (_profileSnapshotBeforeSession != null) {
      predictorModule.updateProfile(_profileSnapshotBeforeSession!);
      await saveProfileToStorage(_profileSnapshotBeforeSession!);
    }
  }

  /// Commits the newly analyzed UserProfileModel to storage after session completion.
  Future<void> commitProfilePostSession(UserProfileModel profile) async {
    predictorModule.updateProfile(profile);
    await saveProfileToStorage(profile);
  }

  /// Convenience passthrough for the Pre-Sleep Setup BLoC to evaluate wake-up health.
  WakeTimeHealthEvaluation previewWakeTimeHealth({
    required DateTime sleepStartTime,
    required DateTime targetWakeTime,
    required PreSleepPhysicalState physicalState,
    required SleepPresetType preset,
  }) {
    return predictorModule.evaluateWakeTimeHealthPreview(
      sleepStartTime: sleepStartTime,
      targetWakeTime: targetWakeTime,
      physicalState: physicalState,
      preset: preset,
    );
  }

  void startSleepSession({
    required DateTime sleepStartTime,
    required DateTime targetWakeTime,
    required PreSleepPhysicalState physicalState,
    required SleepPresetType preset,
    required bool enableAnalysisMode,
  }) {
    _sessionStartTime = sleepStartTime;
    DateTime normalizedWake = targetWakeTime;
    while (!normalizedWake.isAfter(sleepStartTime)) {
      normalizedWake = normalizedWake.add(const Duration(days: 1));
    }
    _targetWakeTime = normalizedWake;
    _physicalState = physicalState;
    _activePreset = preset;
    _profileSnapshotBeforeSession = predictorModule.currentProfile.copyWith();
    _routeToModule2ActiveProbeFunction = false;
    _cumulativePhaseShiftMinutes = 0.0;
    _measuredCyclesTonight.clear();

    analysisModule = AnalysisProbeModule(
      isEnabled: enableAnalysisMode,
      micSampleRateHz: analysisModule.micSampleRateHz,
      completedProbesCount:
          predictorModule.currentProfile.completedAnalysisProbesCount,
    );
  }

  void onMicrophonePcmChunkReceived(List<double> rawMonoPcmSamples) {
    if (!analysisModule.isEnabled) return;
    analysisModule.ingestMicrophonePcmChunk(
      rawMonoPcmSamples,
      calibrated30dBaAmplitude:
          predictorModule.currentProfile.calibrated30dBaAmplitude,
    );
  }

  Future<EngineUnifiedTickOutput> processEngineTick({
    required DateTime currentTime,
    double tickIntervalSeconds = SleepEngineConstants.defaultEngineTickSeconds,
  }) async {
    final DateTime start = _sessionStartTime ?? currentTime;
    final DateTime wake = _targetWakeTime ??
        currentTime.add(
          const Duration(
            hours: SleepEngineConstants.defaultFallbackSessionHours,
          ),
        );

    final PredictedSleepStateFrame sleepFrame =
        predictorModule.evaluateSleepAndProposeSound(
      currentTime: currentTime,
      sleepStartTime: start,
      targetWakeTime: wake,
      physicalState: _physicalState,
      preset: _activePreset,
      enforceMicrophoneFrequencySplit: analysisModule.isEnabled,
      cumulativePhaseShiftMinutes: _cumulativePhaseShiftMinutes,
      measuredCycleDurationsTonight: _measuredCyclesTonight,
    );

    AnalysisModuleEvaluationResult analysisResult;
    if (!_routeToModule2ActiveProbeFunction) {
      analysisResult = analysisModule.evaluatePassiveMonitoringStep(
        currentSleepFrame: sleepFrame,
        currentProfile: predictorModule.currentProfile,
        physicalState: _physicalState,
      );
      if (analysisResult.shouldSwitchToActiveProbeFunction) {
        _routeToModule2ActiveProbeFunction = true;
      }
    } else {
      analysisResult = analysisModule.executeActiveProbeStep(
        currentSleepFrame: sleepFrame,
        currentProfile: predictorModule.currentProfile,
        physicalState: _physicalState,
        tickIntervalSeconds: tickIntervalSeconds,
      );
      if (analysisResult.shouldRevertToPassiveFunction) {
        _routeToModule2ActiveProbeFunction = false;
      }
    }

    bool profileUpdated = false;
    if (analysisResult.updatedUserProfile != null) {
      profileUpdated = true;
      final UserProfileModel newProfile = analysisResult.updatedUserProfile!;
      predictorModule.updateProfile(newProfile);

      if (analysisResult.measuredDebiasedCycleDurationMin != null) {
        final double actualElapsedCycleDuration =
            (sleepFrame.elapsedMinutesSinceSessionStart -
                    sleepFrame.currentCycleStartElapsedMin)
                .clamp(
          SleepEngineConstants.minValidCycleDurationMin,
          SleepEngineConstants.maxValidCycleDurationMin,
        );
        _measuredCyclesTonight[sleepFrame.currentCycleIndex] =
            actualElapsedCycleDuration;
      }
      if (analysisResult.phaseShiftOffsetAddedMin != null) {
        _cumulativePhaseShiftMinutes += analysisResult.phaseShiftOffsetAddedMin!;
      }
      await saveProfileToStorage(newProfile);
    }

    final SoundSynthesisRecipe mergedRecipe = _mergeAcousticRecipes(
      baseRecipe: sleepFrame.baseSoundRecipe,
      probeOverlay: analysisResult.probeOverlaySoundRecipe,
      enforceMicSplit: analysisModule.isEnabled,
    );
    _latestMergedRecipe = mergedRecipe;

    return EngineUnifiedTickOutput(
      predictionFrame: sleepFrame,
      analysisFrame: analysisResult,
      mergedSpeakerRecipe: mergedRecipe,
      profileWasUpdatedThisTick: profileUpdated,
      activeProfile: predictorModule.currentProfile,
    );
  }

  Float32List generateNextSpeakerPcmChunk(int sampleCount) {
    final SoundSynthesisRecipe activeRecipe = _latestMergedRecipe ??
        SoundSynthesisRecipe(
          targetVolumeDba: SleepEngineConstants.defaultCycleMaskingDba,
          digitalLinearGain: predictorModule.dbaToDigitalAmplitude(
            SleepEngineConstants.defaultCycleMaskingDba,
          ),
          spectralSlopeBeta: SleepEngineConstants.defaultCycleSlopeBeta,
          lowPassCutoffHz: SleepEngineConstants.fallbackSynthesizerLowPassHz,
        );
    return audioSynthesizer.synthesizePcmBuffer(sampleCount, activeRecipe);
  }

  SoundSynthesisRecipe _mergeAcousticRecipes({
    required SoundSynthesisRecipe baseRecipe,
    required SoundSynthesisRecipe? probeOverlay,
    required bool enforceMicSplit,
  }) {
    if (probeOverlay == null) {
      return baseRecipe;
    }

    final double mergedDba =
        math.max(baseRecipe.targetVolumeDba, probeOverlay.targetVolumeDba);
    final double mergedGain = predictorModule.dbaToDigitalAmplitude(mergedDba);

    final double safeCutoffHz = math
        .min(
          baseRecipe.lowPassCutoffHz,
          probeOverlay.lowPassCutoffHz,
        )
        .clamp(
          SleepEngineConstants.minMergedLowPassCutoffHz,
          enforceMicSplit
              ? SleepEngineConstants.activeProbeMaxLowPassHz
              : SleepEngineConstants.unconstrainedMergedMaxLowPassHz,
        );

    return SoundSynthesisRecipe(
      targetVolumeDba: mergedDba,
      digitalLinearGain: mergedGain,
      spectralSlopeBeta:
          0.5 * (baseRecipe.spectralSlopeBeta + probeOverlay.spectralSlopeBeta),
      lowPassCutoffHz: safeCutoffHz,
      highPassCutoffHz: probeOverlay.highPassCutoffHz,
      modulationFreqHz: probeOverlay.modulationFreqHz,
      modulationDepthDb: probeOverlay.modulationDepthDb,
      enable50msN3Pulses: false,
      enableMorningMelodicHarmonics: false,
      melodicHarmonicMixRatio: 0.0,
    );
  }
}