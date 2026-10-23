// FILE: lib/core/sleep_engine_constants.dart
// Centralized Scientific, Psychoacoustic, Kalman & DSP Constants for the Sleep Engine.
// Every tunable number is isolated and documented here.

abstract final class SleepEngineConstants {
  // ===========================================================================
  // 1. PERSISTENCE & AUDIO ENGINE CADENCE CONSTANTS
  // ===========================================================================

  /// Key used by SleepProfileStorageAdapter (SharedPreferences) to persist profile JSON.
  static const String profileStorageKey = 'sleep_tracker_user_profile_v1';

  /// Default heartbeat tick interval (in seconds) driven by the Flutter BLoC timer.
  static const double defaultEngineTickSeconds = 1.0;

  /// Default fallback sleep session target duration (in hours) if none is provided.
  static const int defaultFallbackSessionHours = 8;

  /// Default speaker output sample rate in Hz (48 kHz standard on Android AAudio/Oboe).
  static const int defaultSpeakerSampleRateHz = 48000;

  /// Default microphone capture sample rate in Hz (16 kHz gives an 8 kHz Nyquist ceiling,
  /// which covers the 2,500 - 7,500 Hz bedsheet rustle band at 1/3rd the CPU cost).
  static const int defaultMicSampleRateHz = 16000;

  // ===========================================================================
  // 2. ANTHROPOMETRIC & SURVEY BOUNDS (OHAYON ET AL., 2004; MCTQ)
  // ===========================================================================

  /// Clamping bounds for user age (in years) to keep normative regressions valid.
  static const int minValidAgeYears = 13;
  static const int maxValidAgeYears = 95;

  /// Clamping bounds for user height (in centimeters) and conversion to meters.
  static const double minValidHeightCm = 120.0;
  static const double maxValidHeightCm = 230.0;
  static const double cmPerMeter = 100.0;

  /// Clamping bounds for user weight (in kilograms).
  static const double minValidWeightKg = 35.0;
  static const double maxValidWeightKg = 200.0;

  /// Reference young-adult baseline age (20 years) for Ohayon et al. (2004) regressions.
  static const int normativeReferenceAgeYears = 20;

  /// Years per decade (10.0) used for per-decade slow-wave sleep & cycle regressions.
  static const double yearsPerDecade = 10.0;

  /// Normative Sleep Onset Latency (SOL) at age 20 (in minutes) and annual increase
  /// when the user selects "I don't know" on the onboarding latency question.
  static const double normativeBaseSolAtRefAgeMin = 13.5;
  static const double normativeSolIncreasePerYearMin = 0.09;

  /// Mapped SOL priors (in minutes) for explicit onboarding MCQ answers.
  static const double surveySolFastMin = 8.0;
  static const double surveySolNormalMin = 14.5;
  static const double surveySolSlowMin = 26.0;
  static const double surveySolVerySlowMin = 38.0;

  /// Normative Cycle 1 Slow-Wave Sleep (N3) fraction at age 20 (32% of Cycle 1)
  /// and its linear decline per decade of adult age (~1.8% per decade).
  static const double normativeBaseN3FractionAtRefAge = 0.32;
  static const double normativeN3DeclinePerDecade = 0.018;
  static const double minBaseN3Fraction = 0.14;
  static const double maxBaseN3Fraction = 0.36;

  /// Population mean ultradian sleep cycle period (in minutes) and mapped MCQ priors.
  static const double defaultBaselineCycleMin = 90.0;
  static const double surveyShortCycleMin = 82.0;
  static const double surveyLongCycleMin = 100.0;

  /// Age-related ultradian cycle shortening per decade over age 20 (in minutes).
  static const double cycleDeclinePerDecadeMin = 0.6;

  /// Initial Kalman variance P_00 (in min^2) for baseline cycle length tau_user:
  /// - 16.0 (SD = 4.0 min) when user explicitly states their cycle rhythm.
  /// - 36.0 (SD = 6.0 min) when user selects "I don't know" (enables faster learning).
  static const double knownCycleInitialKalmanVar = 16.0;
  static const double unknownCycleInitialKalmanVar = 36.0;

  /// Initial Kalman variance (in min^2) for each of the 4 physical-state offsets.
  static const double defaultStateOffsetInitialKalmanVar = 12.0;

  /// Mapped Auditory Arousal Threshold (AAT) offsets (in dB) for noise sensitivity MCQ.
  static const double surveyLightSleeperAatOffsetDb = -3.5;
  static const double surveyAverageSleeperAatOffsetDb = 0.0;
  static const double surveyDeepSleeperAatOffsetDb = 3.5;

  /// Normative AAT stability adjustments when sensitivity is "I don't know":
  /// Arousal threshold drops by 0.45 dB per decade of age and by 0.15 dB per BMI
  /// unit above 27.0 kg/m^2 (up to a maximum BMI penalty of 2.0 dB).
  static const double aatDeclinePerDecadeDb = 0.45;
  static const double elevatedBmiThreshold = 27.0;
  static const double aatPenaltyPerBmiUnitOverThresholdDb = 0.15;
  static const double maxBmiAatPenaltyDb = 2.0;
  static const double minAatOffsetDb = -6.0;
  static const double maxAatOffsetDb = 6.0;

  /// Default habitual circadian anchors (in minutes from 00:00 midnight) when
  /// the user selects "I don't know": 1410.0 = 23:30 (11:30 PM), 450.0 = 07:30 AM.
  static const double defaultHabitualBedtimeMinFromMidnight = 1410.0;
  static const double defaultHabitualWakeMinFromMidnight = 450.0;

  /// Speaker calibration constants: digital linear amplitude [0.0001 - 0.25] that
  /// produces 30.0 dBA (barely audible perceptual threshold in a quiet bedroom).
  static const double referenceCalibrationDba = 30.0;
  static const double defaultCalibrated30dBaDigitalAmp = 0.008;
  static const double minCalibrated30dBaDigitalAmp = 0.0001;
  static const double maxCalibrated30dBaDigitalAmp = 0.25;

  /// Default linear cycle progression coefficient c_1 (minutes added per cycle index
  /// relative to the middle cycle index 2.5).
  static const double defaultLinearCycleCurveCoeff = 1.5;
  static const double cycleCurveCenterIndex = 2.5;

  /// Literature-backed initial state vectors for the 4 non-baseline physical states
  /// ordered as: [HeavyWorkout, HeavyMealBeforeBed, LowExhaustion, HighCognitiveLoad].
  static const List<double> priorStateCycleDurationOffsetsMin = <double>[
    7.5, // Heavy Workout: +7.5 min in early cycles due to SWS/GH rebound
    5.0, // Heavy Meal: +5.0 min in Cycle 1 due to delayed autonomic cooling
    -5.0, // Low Exhaustion: -5.0 min shorter early cycles due to low Process S
    6.0, // High Cognitive Load: +6.0 min from synaptic replay & REM demand
  ];

  static const List<double> priorStateSolMultipliers = <double>[
    -0.20, // Heavy Workout: -20% faster sleep onset from adenosine load
    0.35, // Heavy Meal: +35% slower sleep onset from thermic digestion
    0.30, // Low Exhaustion: +30% slower sleep onset from low homeostatic drive
    0.10, // High Cognitive Load: +10% slower onset from cortical hyperarousal
  ];

  static const List<double> priorStateN3Multipliers = <double>[
    0.16, // Heavy Workout: +16% N3 deep sleep duration in Cycles 1-2
    -0.15, // Heavy Meal: -15% shallower N3 deep sleep in Cycle 1
    -0.18, // Low Exhaustion: -18% N3 deep sleep duration
    0.10, // High Cognitive Load: +10% slow-wave activity in Cycle 1
  ];

  // ===========================================================================
  // 3. CIRCADIAN MISALIGNMENT & SLEEP ONSET LATENCY (SOL) CONSTANTS
  // ===========================================================================

  /// Wake Maintenance Zone (WMZ / "Forbidden Zone for Sleep", Strogatz et al., 1987):
  /// Occurs when attempting to sleep between 0.25 and 4.5 hours EARLIER than habitual
  /// bedtime, peaking at -1.75 hours with a Gaussian standard deviation of 0.85 hours
  /// and adding up to +14.0 minutes to Sleep Onset Latency.
  static const double wmzLowerBoundShiftHours = -4.5;
  static const double wmzUpperBoundShiftHours = -0.25;
  static const double wmzAcousticBoostThresholdHours = -0.5;
  static const double wmzPeakCenterShiftHours = -1.75;
  static const double wmzGaussianWidthHours = 0.85;
  static const double wmzMaxSolPenaltyMin = 14.0;

  /// Elevated Process S when sleeping LATER than habitual bedtime (> +0.5 hours):
  /// Compresses SOL exponentially at rate 0.16 per hour down to 45% of baseline SOL.
  static const double lateBedtimeThresholdHours = 0.5;
  static const double lateBedtimeSolDecayRatePerHour = 0.16;
  static const double minLateBedtimeSolCompressionFactor = 0.45;

  /// Physiological clamping bounds for predicted Sleep Onset Latency (in minutes).
  static const double minPredictedSolMin = 4.0;
  static const double maxPredictedSolMin = 60.0;

  // ===========================================================================
  // 4. ULTRADIAN CYCLE ARCHITECTURE & STAGE PACING CONSTANTS
  // ===========================================================================

  /// Exponential decay rate (0.35) governing how quickly pre-sleep physical state
  /// duration offsets fade across consecutive cycles (Cycle 1 -> Cycle K).
  static const double stateEffectCycleDecayRate = 0.35;

  /// Physiological clamping bounds for a single ultradian cycle duration (in minutes).
  static const double minValidCycleDurationMin = 65.0;
  static const double maxValidCycleDurationMin = 125.0;

  /// Minimum net sleep window (in minutes) required to run multi-cycle optimization,
  /// and candidate cycle count search bounds [3..7] (with max 10 cycles for long sessions).
  static const double minNetSleepWindowMin = 90.0;
  static const int minCandidateCycles = 3;
  static const int maxCandidateCycles = 7;
  static const int defaultCandidateCycles = 5;
  static const int maxSessionCycleSearchLimit = 10;

  /// Safe physiological entrainment bandwidth for acoustic stage pacing (+/- 8%):
  /// Cycle duration can be compressed to 0.92x or stretched to 1.08x to land cleanly
  /// on targetWakeTime without inducing sleep fragmentation.
  static const double minStagePacingFactor = 0.92;
  static const double maxStagePacingFactor = 1.08;
  static const double muscleRepairMinPacingFactor = 0.96;

  /// Ultradian intra-cycle stage partition fractions (summing to 1.0):
  /// - Initial N1 entry: first 4.0% of cycle
  /// - Descending light sleep (N1 + N2_desc): first 20.0% of cycle
  /// - Ascending light sleep (N2_asc): 18.0% of cycle following N3
  /// - Post-REM Fragile Boundary Trough (N1 micro-arousal window): final 5.5% (~5 min)
  static const double n1EntryFractionOfCycle = 0.04;
  static const double descendingLightSleepFraction = 0.20;
  static const double ascendingLightSleepFraction = 0.18;
  static const double postRemFragileTroughFraction = 0.055;
  static const double minRemFractionAfterAscending = 0.05;
  static const double maxRemEndFractionOfCycle = 0.96;

  /// N3 slow-wave sleep scaling across the night:
  /// - Late bedtime (> +0.5h) adds +4% N3 rebound per hour of delay (up to +12%).
  /// - N3 share decays exponentially across cycle index k at rate 0.42.
  static const double lateSleepN3BoostPerHour = 0.04;
  static const double maxLateSleepN3BoostFraction = 0.12;
  static const double n3ExponentialDecayRatePerCycle = 0.42;
  static const double minCycleN3Fraction = 0.03;
  static const double maxCycleN3Fraction = 0.42;

  /// Duration before targetWakeTime (in minutes) when WakeUpFresh enters Pre-Wake Priming.
  static const double preWakePrimingStageWindowMin = 25.0;

  // ===========================================================================
  // 5. AUDITORY AROUSAL THRESHOLD (AAT) MODEL CONSTANTS (ERMIS ET AL., 2010)
  // ===========================================================================

  /// Clinical baseline Auditory Arousal Thresholds (in dBA at pillow distance)
  /// across sleep stages prior to applying personal and physical-state offsets.
  static const double aatWakeOnsetDba = 32.0;
  static const double aatLightTroughN1Dba = 38.5;
  static const double aatN2LightSleepDba = 54.0;
  static const double aatRemSleepDba = 64.0;
  static const double aatN3DeepSleepDba = 76.0;

  /// Physical-state AAT modifiers (in dB):
  static const double aatLowExhaustionShiftDb = -4.0;
  static const double aatHeavyWorkoutShiftDb = 2.5;
  static const double aatHeavyMealShiftDb = -2.0;

  /// Clamping bounds for estimated AAT and speaker output dBA.
  static const double minEstimatedAatDba = 32.0;
  static const double maxEstimatedAatDba = 85.0;
  static const double minSpeakerOutputDba = 25.0;
  static const double maxSpeakerOutputDba = 75.0;

  // ===========================================================================
  // 6. ACOUSTIC CURVES & PRESET SYNTHESIS CONSTANTS
  // ===========================================================================

  /// Frequency Split Ceiling (Hz): When Analysis Mode microphone is active, the speaker
  /// low-pass filter is strictly capped at 1,150 Hz (1,100 Hz during active probing)
  /// so zero speaker energy leaks into the >2,500 Hz microphone detection band.
  static const double speakerMicSplitMaxLowPassHz = 1150.0;
  static const double activeProbeMaxLowPassHz = 1100.0;
  static const double minSafeLowPassCutoffHz = 300.0;
  static const double minMergedLowPassCutoffHz = 350.0;
  static const double unconstrainedMergedMaxLowPassHz = 2500.0;

  /// Sleep Onset (Down-Regulation) curve parameters:
  static const double onsetBaseStartDba = 41.5;
  static const double onsetWmzBoostDb = 2.0;
  static const double onsetTargetEndDba = 35.0;
  static const double onsetUnconstrainedMaxLowPassHz = 2400.0;
  static const double onsetMinLowPassHz = 480.0;
  static const double defaultHighPassCutoffHz = 60.0;
  static const double onsetStartBreathFreqHz = 0.12; // 7.2 breaths/min
  static const double onsetBreathFreqDropHz = 0.03; // Slows to 0.09 Hz (5.4 breaths/min)
  static const double onsetInitialModulationDepthDb = 2.5;
  static const double onsetSlopeBetaWmz = 1.35; // Warmer pink-brown mix in WMZ
  static const double onsetSlopeBetaNormal = 1.15;

  /// Morning Pre-Wake Priming & Awakening Ramp parameters (McFarlane et al., 2020):
  static const double morningWakeWindowBeforeTargetMin = 30.0;
  static const double morningWakePostTargetGraceMin = -15.0;
  static const double morningMelodicCrossfadeWindowMin = 12.0;
  static const double morningWakeStartDba = 34.0;
  static const double morningWakeAddedDbaSpan = 22.0; // Ramps from 34 -> 56 dBA
  static const double morningWakeCurveExponent = 1.6;
  static const double morningWakeBaseLowPassHz = 500.0;
  static const double morningWakeAddedLowPassHz = 2000.0;
  static const double morningWakeMinLowPassClampHz = 450.0;
  static const double cycleUnconstrainedMaxLowPassHz = 3200.0;
  static const double morningWakeBaseHighPassHz = 120.0;
  static const double morningWakeAddedHighPassHz = 100.0;
  static const double morningWakeSlopeBeta = 1.0;
  static const double morningMelodicPulseFreqHz = 1.80; // 1.80 Hz = 108 BPM rhythm
  static const double morningMelodicModulationDepthDb = 3.5;

  /// Nocturnal stage-specific synthesis parameters:
  static const double heavyMealOrHighBmiMaskingBoostDb = 2.0;
  static const int maxCycleIndexForN3Pulses = 2; // Ngo et al. (2013): Cycles 1 & 2
  static const double n3PulseActiveDba = 45.0;
  static const double n3PassiveShieldDba = 36.0;
  static const double n3SlopeBetaMuscleRepair = 1.30;
  static const double n3SlopeBetaCognitive = 1.05;
  static const double n3LowPassCutoffHz = 520.0;
  static const double n3HighPassCutoffHz = 55.0;
  static const double n3SlowOscillationFreqHz = 0.80; // 0.8 Hz slow-wave rhythm
  static const double n3PulseModulationDepthDb = 4.5;

  /// REM Dreaming acoustic shield parameters:
  static const double remShieldBaseDba = 34.5;
  static const double remSlopeBeta = 1.25;
  static const double remLowPassCutoffHz = 550.0;

  /// Ascending N2 light sleep & cycle-shortening parameters:
  static const double shortenCyclePacingThreshold = 0.98;
  static const double ascLightBaseDba = 35.0;
  static const double ascShortenSlopeBeta = 1.0;
  static const double ascNormalSlopeBeta = 1.15;
  static const double ascShortenLowPassHz = 950.0;
  static const double ascNormalLowPassHz = 650.0;
  static const double ascShortenHighPassHz = 180.0;
  static const double ascNormalHighPassHz = 65.0;

  /// Default light sleep / trough masking parameters:
  static const double defaultCycleMaskingDba = 35.0;
  static const double defaultCycleSlopeBeta = 1.15;
  static const double defaultCycleLowPassHz = 680.0;
  static const double fallbackSynthesizerLowPassHz = 800.0;

  // ===========================================================================
  // 7. MODULE 2: ANALYSIS MODE & MICROPHONE RUSTLE DETECTION CONSTANTS
  // ===========================================================================

  /// Number of early cycles rotated across nights for internal boundary probing (2: Cycle 1 & 2).
  static const int numRotatableProbeCycles = 2;

  /// High-Pass Butterworth Biquad Filter cutoff (2,500 Hz) and maximally flat Q (1/sqrt(2)).
  /// Isolates high-frequency bedsheet/pillow friction while rejecting <1,200 Hz speaker sound.
  static const double micHighPassCutoffHz = 2500.0;
  static const double butterworthQFactor = 0.70710678;

  /// Numerical safety floors for RMS-to-dBA logarithmic conversion.
  static const double minRmsNumericalEpsilon = 1e-7;
  static const double minRefAmpNumericalEpsilon = 1e-5;

  /// Microphone high-frequency (>2.5 kHz) noise floor initialization, clamping, and
  /// asymmetric exponential smoothing alphas (fast downward = 0.90, slow upward = 0.995).
  static const double initialHighFreqNoiseFloorDba = 24.0;
  static const double minTrackedMicDba = 18.0;
  static const double maxTrackedMicDba = 85.0;
  static const double floorFastDownwardSmoothingAlpha = 0.90;
  static const double floorSlowUpwardSmoothingAlpha = 0.995;

  /// Probe window scheduling relative to predicted cycle boundary:
  /// Starts 12.0 minutes before predicted boundary; times out after 24.0 minutes
  /// (or 12.0 minutes past predicted boundary) as a right-censored observation.
  static const double probeEntryMinutesBeforeBoundary = 12.0;
  static const double probeEntryMinutesAfterBoundary = -10.0;
  static const double probeMaxWindowDurationMin = 24.0;
  static const double probeTimeoutMinutesAfterBoundary = -12.0;

  /// Sub-threshold acoustic probe stepping parameters:
  /// Starts at 34.0 dBA and steps up by +1.0 dB every 0.75 min (45 seconds) up to a
  /// strict sub-awakening ceiling of 44.0 dBA (or 40.0 dBA on low-exhaustion days).
  static const double probeStartVolumeDba = 34.0;
  static const double probeNormalCeilingDba = 44.0;
  static const double probeLowExhaustionCeilingDba = 40.0;
  static const double probePersonalAatOffsetScaling = 0.4;
  static const double probeMinAllowedCeilingDba = 38.5;
  static const double probeMaxAllowedCeilingDba = 45.0;
  static const double probeStepIntervalMin = 0.75;
  static const double probeStepSizeDb = 1.0;

  /// Bedsheet Rustle Signature Verification Thresholds:
  /// Requires a >= +8.0 dB high-frequency SNR spike lasting between 0.8 and 4.5 seconds
  /// (or immediate confirmation after 1.5 seconds at >= +9.0 dB SNR).
  static const double rustleDetectionSnrThresholdDb = 8.0;
  static const double rustleImmediateConfirmSnrDb = 9.0;
  static const double minValidRustleDurationSec = 0.8;
  static const double maxValidRustleDurationSec = 4.5;
  static const double immediateConfirmRustleMinSec = 1.5;
  static const double immediateConfirmRustleMaxSec = 4.0;

  /// Reaction Latency Debiasing & Micro-Arousal Phase-Shift Constants:
  /// - Subtract [0.4 to 2.2] minutes from detection timestamp based on probe dBA.
  /// - Add 1.2 minutes phase-shift offset to subsequent cycles after a posture shift.
  static const double minReactionDebiasMin = 0.4;
  static const double addedReactionDebiasSpanMin = 1.8;
  static const double postProbeMicroArousalPhaseShiftMin = 1.2;

  /// Active probe acoustic synthesis parameters (<1,050 Hz warm ocean-like swell):
  static const double probeSoundSlopeBeta = 1.10;
  static const double probeSoundLowPassHz = 1050.0;
  static const double probeSoundHighPassHz = 80.0;
  static const double probeSoundSwellFreqHz = 0.25;
  static const double probeSoundSwellDepthDb = 1.8;

  // ===========================================================================
  // 8. KALMAN / RECURSIVE LEAST SQUARES (RLS) BAYESIAN LEARNING CONSTANTS
  // ===========================================================================

  /// Observation noise variance R = sigma_obs^2 = 9.0 min^2 (SD = 3.0 min) and
  /// nightly process drift variance Q = 0.15 min^2 for seasonal adaptation.
  static const double kalmanObservationNoiseVariance = 9.0;
  static const double kalmanProcessDriftVariance = 0.15;

  /// Clamping bounds for learned user parameters and Kalman variances:
  static const double minLearnedBaselineCycleMin = 72.0;
  static const double maxLearnedBaselineCycleMin = 115.0;
  static const double minLearnedStateOffsetMin = -20.0;
  static const double maxLearnedStateOffsetMin = 25.0;
  static const double minKalmanTauVariance = 1.5;
  static const double maxKalmanTauVariance = 36.0;
  static const double minKalmanStateVariance = 1.5;
  static const double maxKalmanStateVariance = 25.0;

  // ===========================================================================
  // 9. PROCEDURAL DSP SYNTHESIZER CONSTANTS (PAUL KELLET + CYTOMIC SVF)
  // ===========================================================================

  /// Minimum low-pass cutoff (120 Hz) and Nyquist safety fraction (0.45 * Fs).
  static const double minSynthesizerLowPassHz = 120.0;
  static const double nyquistSafetyFraction = 0.45;

  /// Cytomic State-Variable Filter Butterworth damping factor k = sqrt(2) = 1.41421356.
  static const double svfButterworthDampingK = 1.41421356;

  /// Ngo et al. (2013) N3 Slow-Oscillation Pink-Noise Pulse Envelope Constants:
  /// 50 ms pulse width (0.050 s) with 5 ms raised-cosine ramps (0.005 s),
  /// peak boost multiplier (1.8), and inter-pulse masking floor ratio (0.35).
  static const double n3PulseDurationSeconds = 0.050;
  static const double n3PulseCosineRampSeconds = 0.005;
  static const double n3PulsePeakBoostMultiplier = 1.8;
  static const double n3InterPulseFloorGainRatio = 0.35;

  /// Paul Kellet 6-stage IIR Pinking Filter poles, input gains, and output scaling
  /// (produces 1/f Pink Noise accurate within +/- 0.05 dB across 9.5 octaves):
  static const double kelletP0Pole = 0.99886;
  static const double kelletP0Gain = 0.0555179;
  static const double kelletP1Pole = 0.99332;
  static const double kelletP1Gain = 0.0750759;
  static const double kelletP2Pole = 0.96900;
  static const double kelletP2Gain = 0.1538520;
  static const double kelletP3Pole = 0.86650;
  static const double kelletP3Gain = 0.3104856;
  static const double kelletP4Pole = 0.55000;
  static const double kelletP4Gain = 0.5329522;
  static const double kelletP5Pole = -0.7616;
  static const double kelletP5Gain = 0.0168980;
  static const double kelletWhiteFeedforwardGain = 0.5362;
  static const double kelletState6WhiteGain = 0.115926;
  static const double kelletOutputNormalizationGain = 0.04;

  /// One-pole leaky integrator coefficients for 1/f^2 Brown Noise synthesis:
  static const double brownLeakyStepGain = 0.02;
  static const double brownLeakyDenominator = 1.02;
  static const double brownOutputBoostGain = 2.5;

  /// Spectral slope beta bounds (1.0 = pure Pink Noise, 2.0 = pure Brown Noise).
  static const double minSpectralSlopeBeta = 1.0;
  static const double spectralSlopeBetaSpan = 1.0;

  /// Hard output PCM limiter ceiling (0.98) to prevent digital DAC clipping.
  static const double pcmHardLimiterCeiling = 0.98;

  /// Morning awakening major-pentatonic harmonic frequencies in Hz (C5, E5, G5)
  /// and amplitude scaling (0.25) used when enableMorningMelodicHarmonics is true:
  static const double morningHarmonicFreq1Hz = 523.25;
  static const double morningHarmonicFreq2Hz = 659.25;
  static const double morningHarmonicFreq3Hz = 783.99;
  static const double morningHarmonicBaseAmp = 0.25;

  // ===========================================================================
  // 10. PRE-SLEEP WAKE-UP HEALTH & ALIGNMENT INDICATOR CONSTANTS
  // ===========================================================================

  /// Target hardware media volume fraction (70% = 0.70) and tolerance (+/- 5%)
  /// required during both Quiet-Room Calibration and Active Sleep Sessions so
  /// digital-to-dBA conversion operates in the amplifier's linear sweet spot.
  static const double requiredHardwareVolumeFraction = 0.70;
  static const double hardwareVolumeTolerance = 0.05;

  /// Wake-up alignment health scoring thresholds:
  /// - Optimal cycle count range: 5 to 6 cycles (Green zone)
  /// - Acceptable cycle count: 4 or 7 cycles (Yellow zone cap)
  /// - Insufficient / excessive cycle count: <= 3 cycles (Red zone cap)
  static const int minOptimalCyclesGreen = 5;
  static const int maxOptimalCyclesGreen = 6;
  static const int minAcceptableCyclesYellow = 4;

  /// Phase mismatch fractions relative to total natural sleep duration:
  /// - <= 4.0% mismatch (0.04): Effortless acoustic pacing (Green)
  /// - <= 8.0% mismatch (0.08): Within max safe pacing bandwidth (Yellow-Green)
  /// - > 8.0% mismatch: Exceeds safe pacing limit; user risks waking mid-cycle
  static const double effortlessPacingMismatchFraction = 0.04;
  static const double maxSafePacingMismatchFraction = 0.08;
  static const double severePhaseMismatchFraction = 0.14;

  /// Health score weights and zone cutoffs in [0.0, 1.0]:
  /// - Score >= 0.75 -> GREEN (Healthy & cycle-aligned wake time)
  /// - Score >= 0.45 -> YELLOW (Suboptimal duration or near pacing limit)
  /// - Score < 0.45  -> RED (High sleep inertia / mid-cycle interruption risk)
  static const double wakeHealthGreenThreshold = 0.75;
  static const double wakeHealthYellowThreshold = 0.45;
  static const double durationScoreWeight = 0.55;
  static const double alignmentScoreWeight = 0.45;
  static const double optimalCycleDurationScore = 1.0;
  static const double fourCycleDurationScore = 0.72;
  static const double threeCycleDurationScore = 0.35;
  static const double underThreeCycleDurationScore = 0.10;
}

