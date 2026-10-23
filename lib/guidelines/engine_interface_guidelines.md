### Complete Interface & Method-by-Method Specification for Coding Agents

Coding agents should treat **`SleepEngineUnifier`** as the **single facade entry point** for the entire backend. The Flutter UI and BLoC never need to call `SleepAcousticPredictorModule` or `AnalysisProbeModule` directly—`SleepEngineUnifier` orchestrates both modules internally.

#### 1. `SleepEngineUnifier` (The Primary Facade)

| Method Signature | What It Does Internally | Inputs & Types | Return Value | When BLoC Must Call It |
| --- | --- | --- | --- | --- |
| `Future<UserProfileModel> initializeAndLoadProfile({required OnboardingSurveyInput fallbackSurvey, required bool enableAnalysisModeTonight, int micSampleRateHz = 16000})` | Queries `storageAdapter.readString('sleep_tracker_user_profile_v1')`. If a saved JSON profile exists, deserializes it. If `null` (first app launch), runs `UserProfileModel.fromOnboardingSurvey(fallbackSurvey)` using normative regressions and saves it immediately. Instantiates Module 1 and Module 2. | `fallbackSurvey`: `OnboardingSurveyInput`<br>

<br>`enableAnalysisModeTonight`: `bool`<br>

<br>`micSampleRateHz`: `int` (`16000` or `48000`) | `Future<UserProfileModel>` (the active profile ready for UI display) | **Once** on app startup, AND **once** after the user finishes or edits the Onboarding / Calibration screen. |
| `Future<void> saveProfileToStorage(UserProfileModel profile)` | Serializes `profile.toJson()` to a JSON string and writes it to `SharedPreferences` via `storageAdapter.writeString`. Also call `unifier.predictorModule.updateProfile(profile)` if the user manually edited profile settings in UI. | `profile`: `UserProfileModel` | `Future<void>` | Whenever the user manually edits their physique, habitual bedtime, or room speaker calibration in Settings. |
| `void startSleepSession({required DateTime sleepStartTime, required DateTime targetWakeTime, required PreSleepPhysicalState physicalState, required SleepPresetType preset, required bool enableAnalysisMode})` | Locks in the session parameters, normalizes `targetWakeTime` so it is guaranteed to be in the future relative to `sleepStartTime`, resets `_cumulativePhaseShiftMinutes = 0.0`, clears `_measuredCyclesTonight`, sets `_routeToModule2ActiveProbeFunction = false`, and re-initializes Module 2 for the new night. | `sleepStartTime`: `DateTime`<br>

<br>`targetWakeTime`: `DateTime`<br>

<br>`physicalState`: `PreSleepPhysicalState`<br>

<br>`preset`: `SleepPresetType`<br>

<br>`enableAnalysisMode`: `bool` | `void` | **Once** at the exact moment the user taps **"Start Sleep"** on the Pre-Sleep screen. |
| `void onMicrophonePcmChunkReceived(List<double> rawMonoPcmSamples)` | **Non-blocking DSP ingestion.** Passes the normalized `[-1.0, +1.0]` PCM frame through a 2nd-order Butterworth 2,500 Hz High-Pass Biquad filter, computes RMS energy in the $>2,500\text{ Hz}$ bedsheet-rustle band, converts to dBA, tracks peak dBA since the last tick, and updates the asymmetric rolling room noise floor. | `rawMonoPcmSamples`: `List<double>` (length `800` to `2048` samples per chunk at `16000 Hz`) | `void` | **Continuously (every 50–100 ms)** inside the microphone stream listener (`AudioRecorder.startStream`) when `enableAnalysisMode == true`. |
| `Future<EngineUnifiedTickOutput> processEngineTick({required DateTime currentTime, double tickIntervalSeconds = 1.0})` | **The 1-Second Master State Machine.**<br>

<br>1. Calls Module 1 (`evaluateSleepAndProposeSound`) to get predicted stage, cycle boundaries, and base audio recipe.<br>

<br>2. Checks `_routeToModule2ActiveProbeFunction`: calls Module 2 **Function 1** (`evaluatePassiveMonitoringStep`) during normal sleep, or **Function 2** (`executeActiveProbeStep`) during boundary probing.<br>

<br>3. If Function 2 detects a valid 0.8–4.5s bedsheet rustle, runs the Kalman filter update, updates Module 1's profile, logs the cycle duration and phase shift, persists the new profile to `SharedPreferences`, and switches back to Function 1.<br>

<br>4. Merges Module 1 & Module 2 sound recipes into `_latestMergedRecipe`. | `currentTime`: `DateTime.now()`<br>

<br>`tickIntervalSeconds`: `double` (`1.0`) | `Future<EngineUnifiedTickOutput>` containing prediction, analysis telemetry, merged recipe, and updated profile flag. | **Every 1.0 second** via `Timer.periodic(const Duration(seconds: 1), ...)` while a sleep session is active. |
| `Float32List generateNextSpeakerPcmChunk(int sampleCount)` | Calls `audioSynthesizer.synthesizePcmBuffer(sampleCount, _latestMergedRecipe)` to generate seamless 32-bit float PCM audio samples (`[-0.98, +0.98]`) containing $1/f^\beta$ pink/brown noise, state-variable low-pass/high-pass filtering, breathing envelopes, 50 ms N3 pulses, or morning harmonics. | `sampleCount`: `int` (e.g., `2048` or `4096` frames per buffer request) | `Float32List` of length `sampleCount` | **Continuously** whenever the speaker PCM output buffer requests more audio frames (~every 42–85 ms at `48000 Hz`). |

---

#### 2. Internal Module Breakdown (How Module 1 & Module 2 Interact via Unifier)

1. **Module 1 (`SleepAcousticPredictorModule`):**
* `computeCircadianShiftHours(DateTime sleepStartTime)`: Calculates $\Delta t_{\text{circ}} \in [-12, +12]\text{ hours}$ relative to `habitualBedtimeMin`.
* `predictSleepOnsetLatencyMinutes(...)`: Computes tonight's SOL by combining baseline SOL, pre-sleep physical state multiplier, the **Wake Maintenance Zone (WMZ)** Gaussian penalty (when sleeping $0.25–4.5\text{ hours}$ *earlier* than usual), and **Process S exponential compression** (when sleeping *later* than usual).
* `predictNaturalCycleDurationMinutes(...)`: Computes unstretched cycle duration $D_{n,k}^{\text{pred}}$ for cycle $k$ using baseline $\tau_{\text{user}}$, linear night-progression curve $c_1$, and exponentially decaying physical-state offset $\beta_{\text{state}} e^{-0.35(k-1)}$.
* `evaluateSleepAndProposeSound(...)`: Solves for optimal cycle count $K^* \in \{3..7\}$ and safe stage-pacing stretch factor $\gamma \in [0.92, 1.08]$ ($\pm 8\%$), determines exact intra-cycle stage (`wakeOnset`, `n1LightTransition`, `n2DescendingLight`, `n3SlowWaveDeep`, `n2AscendingLight`, `remDreaming`, `postRemFragileTrough`, or `preWakePriming`), and outputs `PredictedSleepStateFrame`.


2. **Module 2 (`AnalysisProbeModule`):**
* **Function 1 (`evaluatePassiveMonitoringStep`)**: Runs by default. Monitors `currentSleepFrame.minutesUntilCurrentCycleBoundary`. As soon as the sleeper enters the $[-12\text{ min}, +10\text{ min}]$ window of tonight's target probe cycle, sets `shouldSwitchToActiveProbeFunction = true`.
* **Function 2 (`executeActiveProbeStep`)**: Invoked by Unifier once Function 1 triggers. Steps a warm $<1,050\text{ Hz}$ ocean-swell probe tone by $+1.0\text{ dB}$ every $45\text{ seconds}$ from $34\text{ dBA}$ up to the sub-awakening ceiling ($44\text{ dBA}$, or $40\text{ dBA}$ on Low Exhaustion nights). Watches the $>2,500\text{ Hz}$ high-pass mic stream for a $+8\text{ dB}$ SNR spike lasting $0.8–4.5\text{ seconds}$. On detection, immediately drops the probe tone (`probeOverlaySoundRecipe = null`), debiases reaction time, updates `UserProfileModel` via the 5-state Kalman filter, and sets `shouldRevertToPassiveFunction = true`.



---

### Part 3: BLoC Business Logic & Audio/Mic Stream Wiring Blueprint

Give these exact architectural rules to your coding agents for building the Flutter BLoC layer (`SleepSessionBloc` and `UserProfileCubit`):

#### 1. State Management Separation (Two BLoCs / Cubits)

* **`UserProfileCubit` (Persistent Profile & Onboarding State):**
* Holds `UserProfileModel` and `OnboardingSurveyInput`.
* Handles onboarding form submission, acoustic room calibration slider updates (`calibrated30dBaAmplitude`), and manual profile edits in Settings.
* Calls `await unifier.saveProfileToStorage(updatedProfile)` and `unifier.predictorModule.updateProfile(updatedProfile)` whenever any profile field changes.


* **`SleepSessionBloc` (Overnight Real-Time Execution State):**
* **Events:**
* `SleepSessionStarted(PreSleepPhysicalState state, SleepPresetType preset, DateTime targetWakeTime, bool enableAnalysisMode)`
* `SleepSessionTicked(DateTime timestamp)` *(dispatched internally every 1.0s by `Timer.periodic`)*
* `SleepSessionStopped()` *(dispatched when the user dismisses the morning alarm or cancels the session)*


* **States:**
* `SleepSessionIdle`
* `SleepSessionActive(EngineUnifiedTickOutput latestTickOutput)`
* `SleepSessionSummary(UserProfileModel finalProfile, Duration totalSleepDuration, bool cycleWasCalibratedTonight)`





#### 2. Converting Raw Microphone Bytes to Normalized Doubles for `onMicrophonePcmChunkReceived`

Most Flutter microphone plugins (such as `record` v5+) emit `Stream<Uint8List>` encoded as `AudioEncoder.pcm16bits` (16-bit signed little-endian PCM) at `16000 Hz` mono. Your coding agent must convert each `Uint8List` chunk into `List<double>` in `[-1.0, +1.0]` using this helper before calling `unifier.onMicrophonePcmChunkReceived`:

```dart
List<double> convertPcm16BytesToNormalizedDoubles(Uint8List pcm16Bytes) {
  final ByteData byteData = ByteData.sublistView(pcm16Bytes);
  final int sampleCount = pcm16Bytes.lengthInBytes ~/ 2;
  final Float64List normalized = Float64List(sampleCount);
  for (int i = 0; i < sampleCount; i++) {
    final int int16Sample = byteData.getInt16(i * 2, Endian.little);
    normalized[i] = int16Sample / 32768.0;
  }
  return normalized;
}

```

#### 3. Feeding `generateNextSpeakerPcmChunk` to the Android Speaker

To play the procedural float PCM buffer without gaps or clicks on Android, your coding agent should use a raw PCM streaming package such as `flutter_pcm_sound` (or `mp_audio_stream`):

1. Initialize the player at `sampleRate = 48000`, `channelCount = 1`.
2. Register the feed callback: whenever the output buffer drops below `4096` frames, call:
```dart
final Float32List floatPcm = unifier.generateNextSpeakerPcmChunk(2048);

```


3. If the chosen PCM package expects 16-bit integer PCM (`Int16List`), multiply each sample in `floatPcm` by `32767.0` and cast to `int`.

---

### Part 4: User-Adjustable Variables & Constants (UI ↔ BLoC Mapping)

Not all numbers in `SleepEngineConstants` should be locked away—several parameters are specifically designed to be **driven by user UI controls** across 4 screens of your app. Tell your coding agents to wire the following UI elements through BLoC into the engine:

#### Screen 1: Onboarding & Physique Profile Screen (`OnboardingSurveyInput` / `UserProfileModel`)

| UI Element & Label | Engine Field / Variable | UI Control Type | Valid Range & Step | Default / "I Don't Know" Behavior |
| --- | --- | --- | --- | --- |
| **Height** | `OnboardingSurveyInput.heightCm` | Slider or Number Field | `120.0 – 230.0 cm` (step `1.0 cm`) | Default `175.0 cm`. Used with weight to calculate `bmi` for nocturnal masking shield & AAT stability. |
| **Weight** | `OnboardingSurveyInput.weightKg` | Slider or Number Field | `35.0 – 200.0 kg` (step `0.5 kg`) | Default `70.0 kg`. |
| **Age** | `OnboardingSurveyInput.ageYears` | Number Picker | `13 – 95 years` (step `1 year`) | Default `20`. Drives Ohayon et al. (2004) baseline N3 fraction and SOL regressions. |
| **Biological Sex** | `OnboardingSurveyInput.sex` | Segmented Button (`BiologicalSex`) | `male`, `female`, `otherOrUnspecified` | Default `otherOrUnspecified`. |
| **Usual Bedtime** | `habitualBedtimeMinutesFromMidnight` | Time Picker + *"I don't know / Irregular"* checkbox | `0 – 1439 min` (`00:00` to `23:59`) | If checkbox is ticked, pass `null` (uses `defaultHabitualBedtimeMinFromMidnight = 1410.0`). Anchors the Wake Maintenance Zone calculation! |
| **Usual Wake Time** | `habitualWakeMinutesFromMidnight` | Time Picker + *"I don't know"* checkbox | `0 – 1439 min` (`00:00` to `23:59`) | If checkbox is ticked, pass `null` (uses `450.0` [07:30 AM]). |
| **Q1: How long does it usually take you to fall asleep?** | `OnboardingSurveyInput.latencyAnswer` | 5-Option Radio Card (`SurveySleepLatencyOption`) | `fastUnder10Min`, `normal10To20Min`, `slow20To35Min`, `verySlowOver35Min`, **`unknown` ("I don't know")** | Selecting `unknown` computes age-adjusted normative SOL (`13.5 + 0.09 * (age - 20)` min). |
| **Q2: How easily do bedroom noises wake you up?** | `OnboardingSurveyInput.sensitivityAnswer` | 4-Option Radio Card (`SurveyNoiseSensitivityOption`) | `lightSleeperEasilyWoken`, `averageSleeper`, `deepSleeperHardToWake`, **`unknown` ("I don't know")** | Selecting `unknown` computes age- and BMI-adjusted `arousalThresholdOffsetDb`. |
| **Q3: What is your natural sleep cycle length?** | `OnboardingSurveyInput.cycleRhythmAnswer` | 4-Option Radio Card (`SurveyCycleRhythmOption`) | `shortCyclesAround80Min`, `standardCyclesAround90Min`, `longCyclesAround100PlusMin`, **`unknown` ("I don't know")** | Selecting `unknown` initializes $\tau_{\text{user}} \approx 90\text{ min}$ and sets a wider Kalman variance (`36.0`) so Analysis Mode adapts faster on Nights 1–3. |

---

#### Screen 2: Quiet-Room Speaker Calibration Wizard (`UserProfileModel.calibrated30dBaAmplitude`)

| UI Element & Label | Engine Field / Variable | UI Control Type | Valid Range & Step | How BLoC Wires It |
| --- | --- | --- | --- | --- |
| **"Slide until you can barely hear the soft breeze from your pillow"** | `calibrated30dBaAmplitude` | Logarithmic Slider | `0.0001 – 0.25` (Default: `0.008`) | While on this screen, play continuous pink noise using `SoundSynthesisRecipe(targetVolumeDba: 30.0, digitalLinearGain: sliderValue, spectralSlopeBeta: 1.0, lowPassCutoffHz: 800.0)`. When user taps **"Save Calibration"**, update `profile.copyWith(calibrated30dBaAmplitude: sliderValue)` and persist via `unifier.saveProfileToStorage(...)`. |

---

#### Screen 3: Pre-Sleep Nightly Dashboard (`unifier.startSleepSession(...)`)

| UI Element & Label | Engine Parameter | UI Control Type | Options / Range | Scientific Effect on Tonight's Session |
| --- | --- | --- | --- | --- |
| **Target Wake-Up Time** | `targetWakeTime` | Time Picker Wheel | Any future `DateTime` (typically 4 to 10 hours ahead) | Determines optimal cycle count $K^*$, computes the $\pm 8\%$ stage-pacing stretch factor $\gamma$, and schedules the 30-minute Pre-Wake Priming + 108 BPM Melodic Ramp. |
| **Sleep Goal Preset** | `preset` (`SleepPresetType`) | 4-Card Selector | 1. `deepSleepMuscleRepair`<br>

<br>2. `deepSleepCognitiveMemory`<br>

<br>3. `basicBalancedSleep`<br>

<br>4. `wakeUpFreshAntiInertia` | Selects the nocturnal spectral slope $\beta$, activates/deactivates 0.8 Hz 50 ms N3 pink-noise pulses in Cycles 1–2, and configures morning pre-wake priming. |
| **Today's Physical Status** | `physicalState` (`PreSleepPhysicalState`) | 5-Chip Selector | 1. `normalBaseline`<br>

<br>2. `heavyWorkout`<br>

<br>3. `heavyMealBeforeBed`<br>

<br>4. `lowExhaustion`<br>

<br>5. `highCognitiveLoad` | Shifts tonight's predicted SOL, Cycle 1–2 N3 deep sleep share, cycle duration offsets ($\boldsymbol{\beta}_k$), nocturnal masking volume ($+2\text{ dB}$ for heavy meal), and routes Kalman learning into the matching state covariate! |
| **Run Cycle Analysis Mode Tonight** | `enableAnalysisMode` | Switch Toggle (`bool`) | `true` / `false` | When `true`, caps speaker low-pass filter at $\le 1,150\text{ Hz}$, activates the $>2,500\text{ Hz}$ microphone listener, and runs one 34–44 dBA sub-threshold boundary probe to measure and update personal cycle length. |

---

#### Screen 4: Advanced Audio & Sensitivity Tuning (Optional User Overrides)

If you want to give users an **"Advanced Audio & Detection Settings"** drawer to fine-tune the feel of the app, expose these 3 fields on `UserProfileModel` (or pass them into a user-settings config):

1. **Master Comfort Volume Offset (`UserProfileModel.arousalThresholdOffsetDb`):**
* **UI Control:** Slider labeled *"Sleep Sound & Probe Intensity"* ranging from **`-6.0 dB` (Quieter / Light Sleeper)** to **`+6.0 dB` (Louder / Deep Sleeper)**, step `0.5 dB`.
* **What it adjusts:** Shifts the stage arousal threshold estimate and scales the Analysis Mode probe ceiling (`probePersonalAatOffsetScaling = 0.4`), preventing accidental awakenings if a user discovers they are more sensitive than they answered in the survey.


2. **Learned Cycle Length Override / Reset (`UserProfileModel.baselineCycleMinutes`):**
* **UI Control:** Read-only metric badge showing *"Your Learned Cycle: 92.4 min (Confidence: High)"* with a **"Reset Learned Data"** button.
* **What it adjusts:** Tapping reset restores `baselineCycleMinutes = 90.0`, `stateCycleDurationOffsetsMin = priorStateCycleDurationOffsetsMin`, and `kalmanParameterVariances = [36.0, 12.0, 12.0, 12.0, 12.0]`.


3. **Habitual Bedtime Auto-Sync or Manual Update (`UserProfileModel.habitualBedtimeMin`):**
* **UI Control:** Time picker in Settings allowing the user to update their usual sleep schedule if their lifestyle shifts (e.g., starting university classes or changing workout times), ensuring the **Wake Maintenance Zone** and **Process S** calculations stay aligned with their real circadian rhythm.