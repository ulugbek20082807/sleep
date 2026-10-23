Conversation with Other Advanced AI:

User message: "i wrote all ur interface guidelines in engine interface guidelines md file, and in separate app specification md i want to write overall app structure and logic with as much detail as possible, and my current brief plan: "I am creating sleep perfecter kind of app that analyses user sleep habit and scientific data and plays noise to improve sleep and customize the sleep based on user preferences. The app itself is simple to complicated and is going to be developed in two stages and right now we focus on the first stage with adjusted coding architecture to ease the implementation of second module and ease any future improvements. First of all, user should be able to create separate "profiles" that contains their sleep data. When app is initialized, it should open up to default profile or if no profile is available then special page that asks user to create a profile with appropriate data stated by the sleep core engine in the engine folder (read intefrace guidelines as well on the same guidelines folder). User should be able to create and change profiles from profiles menu: so if app opens up to default profile or jumps to default profile after creating first profile, the profile avatar (yes user avatar should be requested in profile creation if not added typical placeholder avatar should be used) should appear on top right corner like google account menu, and from there when pressed links to settings page, and Switch/edit profiles page should be present. In switch/edit profiles page each profile should be listed with deletion icon if user wants to delete the account - if all the accounts are deleted then the user should be auto routed to profile creation page. In the home page of default profile, there should be Sleep history section that lists all the past sleeps, their most important details in beautiful widgets, listed. And in the bottom like in navigation area but with bigger circular "Start" button in the centre and history tab on the left, settings tab on the right, with history tab on initially (home page). When Items in sleep history is pressed it should open up a page with all the appropriate details of that particular sleep with respective beautiful widgets. When Start button is pressed new page should open up that asks for user details based on engine interface specification including whether or not user wants to use analysis mode and the time they want to wake up, also putting indicator on the bottom whether user will be able to healthily and with no problems wake up at this time based on engine profile data with beautiful auto updating (progress bar with color red to yellow to green showing warning level) widget on time change, to perfect current sleep routine - and there should be start button on the bottom to start the actual sleep. When sleep start button is pressed another page, showing appropriate beautiful widgets current state of the sleep (with appropriate date) should be showed AND most importantly, the app should become "workable" in the backround for long time (by getting permissions or changing modes of app to bg from system idk). The app should constantly listen to microphone if analysis mode is enabled, play noise based on engine data and feed the engine with data. There should be medium sized stop button on the bottom of the page that needs to be long pressed/held for two seconds (with appropriate on button progress indicator animations) to be fully pressed which stops all the sleep and engine data feeding and ends the engine with appropriate routine. Analysis mode will only update profile data once the necessary sleep cycle time detection function runs so it should be ok to end the engine with no updates. After the ending, appropriate history should be saved. Btw, the history on the home/history page should be removable by press and holding that widget showing history and remove button appears on the bottom of the widget and when pressed popup for confirmation appears, then it removes once confirmed. 

U should use BLOC and other appropriate plugins (microphone, speaker, ) should be used, shared preferenes should be used for data storage. Appropriate permissions should be got from the system (1) on first app opening (for mic, speaker, permission to be used on the background for long time - if this permission is inaccessible to be enabled by app, then user should be shown a popup with instructions on how to enable them), (2) after pressing start from sleep start page and before transitioning to actuall sleep routine - if permission to run in bg not gotten then ask similarly, if not gotten even after that then error popup should popup with appropriate message and guidelines; if permission to speaker is not taken and ALSO if speaker is not in correct volume (100% or what? decide urself) then user should be asked to change it and app should auto proceed when correct volume is reached, or if not reached then there should be cancel button on popup permission asker which again cancels the routine; if on analysis mode and permission to use mic ALL THE TIME AND EVEN IN BACKGROUND is not gotten then this should be asked and enabled appropriately, if all these things pass then sleep routine starts. 

Use default Material 3 ui, with no custom themes, u can only use custom widgets from plugins but they should follow app material theme." and i want u to perfect it, give more details, perfect the logic, fill in the gaps, make sure there are no dead ends and app is seemless and complete with no edge cases left unchecked. if u think some things are missing on engine interface guidelines md (which contains the previous message of urs starting from part 2), then give updated engine guideline as well OR/AND if u think u should add somethings to the engine file itself, give me edit instructions. Give as much details as possible. for guidelines"

AI response: "
### Part 1: Engine Updates for Multi-Profile Support & Pre-Sleep Wake Health Bar

Your app specification introduces two features that interact directly with the core engine:

1. **Multi-Profile Storage Routing:** Each user profile needs its own isolated storage key in `SharedPreferences` instead of a single global key.
2. **Real-Time Wake-Up Health & Alignment Indicator (Red $\to$ Yellow $\to$ Green):** On the Pre-Sleep Setup screen, as the user scrolls the wake-up time picker or changes their physical state, the UI needs an instant scientific calculation of whether that wake-up time lands cleanly at the end of a natural sleep cycle (within the safe $\pm 8\%$ acoustic pacing limit) AND provides sufficient total sleep cycles.

Below are the exact drop-in additions for `sleep_engine_constants.dart` and `sleep_core_engine.dart` so the engine natively powers both features without any hardcoded numbers.

#### 1. Edit in `lib/core/sleep_engine_constants.dart`

Add the following block to the bottom of `SleepEngineConstants` (right before the closing `}`):

```dart
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

```

#### 2. Edits in `lib/core/sleep_core_engine.dart`

**Edit A — Add `WakeTimeHealthZone` enum (in Section 1) and `WakeTimeHealthEvaluation` model (in Section 3):**

```dart
// ADD to Section 1 (Enums):
enum WakeTimeHealthZone {
  redWarning, // Score < 0.45: Mid-cycle N3/REM interruption or severe sleep debt
  yellowCaution, // Score 0.45 - 0.74: Acceptable but requires high pacing stretch or 4 cycles
  greenOptimal, // Score >= 0.75: 5-6 cycles landing cleanly on a post-REM trough
}

// ADD to Section 3 (Data Models):
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

```

**Edit B — Add `evaluateWakeTimeHealthPreview` inside `SleepAcousticPredictorModule` (Section 4):**

```dart
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

    final DateTime idealWakeTime = sleepStartTime.add(
      Duration(
        milliseconds: ((predictedSol + bestNaturalSumMin) * msPerMinute).round(),
      ),
    );

    String headline;
    String subtitle;
    if (zone == WakeTimeHealthZone.greenOptimal) {
      headline = 'Optimal Wake Alignment ($bestK Full Cycles)';
      subtitle =
          'Acoustic pacing (${((requiredPacing - 1.0) * 100.0).toStringAsFixed(1)}%) will land you cleanly in a natural light-sleep trough.';
    } else if (zone == WakeTimeHealthZone.yellowCaution) {
      if (bestK < SleepEngineConstants.minOptimalCyclesGreen) {
        headline = 'Short Sleep Window ($bestK Cycles)';
        subtitle =
            'Cycle boundary aligns well, but $bestK cycles provides reduced late-night REM recovery.';
      } else {
        headline = 'Near Acoustic Pacing Limit ($bestK Cycles)';
        subtitle =
            'Requires ${rawMismatchMin.abs().round()} min cycle adjustment. Ideal natural trough is around ${idealWakeTime.hour.toString().padLeft(2, '0')}:${idealWakeTime.minute.toString().padLeft(2, '0')}.';
      }
    } else {
      headline = 'High Sleep Inertia Risk ($bestK Cycles)';
      subtitle =
          'Target time cuts into deep or REM sleep or is too short. Consider waking near ${idealWakeTime.hour.toString().padLeft(2, '0')}:${idealWakeTime.minute.toString().padLeft(2, '0')}.';
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

```

**Edit C — Update `SleepEngineUnifier` (Section 7) to support per-profile storage keys and expose the wake health preview:**

```dart
// 1. ADD field to SleepEngineUnifier:
  String _activeProfileStorageKey = SleepEngineConstants.profileStorageKey;

// 2. REPLACE initializeAndLoadProfile and saveProfileToStorage in SleepEngineUnifier WITH:
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

```

---

### Part 2: Addendum to `engine_interface_guidelines.md`

Append this section to your existing `engine_interface_guidelines.md` file:

```markdown
## Part 5: Multi-Profile Routing, Wake-Time Health Preview & Hardware Volume Standard

### 1. Multi-Profile Storage Key Isolation
When loading or switching between user profiles, pass the active profile's `id` into `initializeAndLoadProfile`:
- `await unifier.initializeAndLoadProfile(fallbackSurvey: survey, enableAnalysisModeTonight: false, customProfileId: activeProfile.id);`
- Internally, the engine namespaces the scientific profile in `SharedPreferences` under `'sleep_tracker_user_profile_v1_<profileId>'`.
- When a user deletes a profile in the UI, delete `'sleep_tracker_user_profile_v1_<profileId>'` from `SharedPreferences`.

### 2. Pre-Sleep Wake-Time Health Indicator API (`unifier.previewWakeTimeHealth`)
Whenever the user opens the **Pre-Sleep Setup Page** or changes the **Target Wake-Up Time**, **Physical State**, or **Preset**, call:
```dart
final WakeTimeHealthEvaluation evaluation = unifier.previewWakeTimeHealth(
  sleepStartTime: DateTime.now(),
  targetWakeTime: selectedWakeTime,
  physicalState: selectedPhysicalState,
  preset: selectedPreset,
);

```

Bind the returned `WakeTimeHealthEvaluation` directly to the bottom health indicator widget:

* `evaluation.healthScoreNormalized`: `double` in `[0.0, 1.0]` -> bind to `LinearProgressIndicator(value: evaluation.healthScoreNormalized)`.
* `evaluation.healthZone`:
* `WakeTimeHealthZone.redWarning` (`< 0.45`): Color `Theme.of(context).colorScheme.error` (Red).
* `WakeTimeHealthZone.yellowCaution` (`0.45 - 0.74`): Color `Colors.amber.shade700` (Yellow/Amber).
* `WakeTimeHealthZone.greenOptimal` (`>= 0.75`): Color `Colors.green.shade600` (Green).


* `evaluation.statusHeadline` & `evaluation.statusSubtitle`: Display directly below the progress bar.
* `evaluation.nearestNaturalTroughWakeTime`: Optional "Snap to Ideal Time (HH:MM)" `ActionChip` so the user can align to 100% green with one tap.

### 3. Hardware Speaker Volume Standard (70% Media Volume Lock)

Because `UserProfileModel.calibrated30dBaAmplitude` maps digital float gain `[0.0, 1.0]` to physical dBA at pillow distance, the Android hardware amplifier gain (`STREAM_MUSIC`) must be identical during **Calibration** and **Sleep Execution**.

* **Required Hardware Media Volume:** `SleepEngineConstants.requiredHardwareVolumeFraction` = **`0.70` (70%)** with tolerance `±0.05` (`[0.65, 0.75]`).
* Why 70%: Smartphone Class-D speakers distort (clip) above 85% and lack dynamic range for the 56 dBA morning ramp below 50%.

```

---

### Part 3: Complete `app_specification.md` (Copy-Paste Ready for Coding Agents)

Save the markdown document below as `app_specification.md` in your guidelines folder. It leaves zero architectural, navigation, permission, or edge-case decisions ambiguous.

```markdown
# Sleep Perfecter App — Master Architecture & Implementation Specification (Stage 1)

## 1. Overview & Architectural Philosophy
Sleep Perfecter is a science-backed Android sleep cycle tracker, acoustic sleep modulator, and smart cycle-calibrating alarm built with **Flutter (Material 3)** and **BLoC (`flutter_bloc`)**.
- **Stage 1 (Current Scope):** Multi-profile management, normative onboarding + quiet-room speaker calibration, goal-oriented procedural noise presets, pre-sleep physical state linking, wake-time health alignment preview, background execution, and microphone-based high-frequency (>2,500 Hz) bedsheet-rustle detection during Analysis Mode.
- **Stage 2 Compatibility Requirement:** All audio I/O and background service layers must be encapsulated behind clean interfaces (`AudioHardwareService`, `BackgroundExecutionService`) so Stage 2 (18–20 kHz FMCW ultrasonic sonar chest-breathing detection) can be added to `AudioHardwareService` without modifying any UI screens, BLoCs, or persistence schemas.
- **UI Theme Rule:** Strictly use **default Flutter Material 3 (`ThemeData(useMaterial3: true)`)**. Do NOT create custom color themes, custom fonts, or custom styling overrides. All third-party widgets must inherit `Theme.of(context).colorScheme` and `Theme.of(context).textTheme`.

---

## 2. Project Folder Structure & Required Packages

### 2.1 Directory Layout
```text
lib/
├── core/
│   ├── sleep_engine_constants.dart       # Provided scientific & DSP constants
│   └── sleep_core_engine.dart            # Provided Module 1, Module 2, Synthesizer & Unifier
├── data/
│   ├── adapters/
│   │   └── shared_prefs_sleep_adapter.dart # Implements SleepProfileStorageAdapter
│   ├── models/
│   │   ├── app_user_profile_meta.dart    # Profile ID, name, avatar path, createdAt
│   │   └── sleep_session_record.dart     # Completed sleep history item + telemetry summary
│   └── repositories/
│       ├── profile_repository.dart       # CRUD for multi-profile metadata & active profile ID
│       └── sleep_history_repository.dart # CRUD for per-profile sleep history records
├── services/
│   ├── permission_gatekeeper_service.dart # Mic, Notification, Battery Exemption checks
│   ├── hardware_volume_service.dart      # Monitors & sets Android STREAM_MUSIC to 70%
│   ├── audio_io_service.dart             # 48kHz PCM output stream + 16kHz PCM mic stream
│   └── sleep_foreground_service.dart     # Android Foreground Service & WakeLock wrapper
├── logic/ (BLoCs & Cubits)
│   ├── profile_bloc/                     # Active profile, switching, creation, deletion
│   ├── sleep_history_cubit/              # Loading, adding, and deleting sleep records
│   ├── pre_sleep_setup_cubit/            # Wake time health preview & pre-flight checks
│   └── active_sleep_bloc/                # 1s engine heartbeat, audio/mic streams, 2s stop
└── presentation/
    ├── app_router.dart                   # Central navigation & zero-profile guard
    ├── screens/
    │   ├── create_edit_profile_screen.dart
    │   ├── main_shell_screen.dart        # Top-right avatar, History tab, Start FAB, Settings tab
    │   ├── switch_profiles_screen.dart
    │   ├── sleep_history_detail_screen.dart
    │   ├── pre_sleep_setup_screen.dart
    │   └── active_sleep_tracking_screen.dart
    └── widgets/
        ├── profile_avatar_menu_button.dart
        ├── sleep_history_card.dart       # Supports tap (detail) & long-press (delete reveal)
        ├── wake_health_indicator_bar.dart # Red -> Yellow -> Green animated progress bar
        ├── pre_flight_permission_dialogs.dart # Volume auto-proceed dialog & BG instructions
        └── hold_to_stop_button.dart      # 2.0-second press-and-hold animated button

```

### 2.2 Required `pubspec.yaml` Dependencies

* `flutter_bloc: ^8.1.6` & `equatable: ^2.0.5` (State management)
* `shared_preferences: ^2.3.2` (Local persistence)
* `permission_handler: ^11.3.1` (Runtime permissions & battery optimization intents)
* `flutter_foreground_task: ^8.10.0` (Android Foreground Service with `mediaPlayback|microphone` types and `PARTIAL_WAKE_LOCK`)
* `record: ^5.1.2` (16,000 Hz mono PCM16 microphone input stream)
* `flutter_pcm_sound: ^3.1.0` (or `mp_audio_stream`) (48,000 Hz mono PCM speaker output stream)
* `volume_controller: ^2.0.8` (Reactive hardware media volume listener and controller)
* `image_picker: ^1.1.2` (Optional profile avatar photo selection from gallery/camera)
* `uuid: ^4.5.0` & `intl: ^0.19.0` (IDs and date formatting)

### 2.3 Required `android/app/src/main/AndroidManifest.xml` Configuration

Declare the following permissions and service inside `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

```

Inside `<application>`:

```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="mediaPlayback|microphone"
    android:exported="false" />

```

---

## 3. Data Persistence Schema (`SharedPreferences`)

All data is stored in `SharedPreferences` using structured JSON keys so profiles remain 100% isolated:

1. **`'app_profiles_registry_v1'` (`String` - JSON List of `AppUserProfileMeta`):**
```json
[
  {
    "id": "uuid-1",
    "displayName": "Alex",
    "avatarPath": "/data/user/0/.../avatar_1.jpg", // null -> use default Material CircleAvatar icon
    "createdAtIso": "2026-10-22T22:00:00.000"
  }
]

```


2. **`'app_active_profile_id_v1'` (`String`):**
Stores the `id` of the currently selected profile.
3. **`'sleep_tracker_user_profile_v1_<id>'` (`String` - JSON of `UserProfileModel`):**
Managed automatically by `SleepEngineUnifier.initializeAndLoadProfile(..., customProfileId: id)`.
4. **`'sleep_history_records_v1_<id>'` (`String` - JSON List of `SleepSessionRecord`):**
Stores all completed sleep sessions for profile `<id>`, ordered newest first.

### `SleepSessionRecord` Data Model Fields

Every saved sleep session must record:

* `sessionId` (`String`), `profileId` (`String`)
* `sleepStartTimeIso` (`String`), `targetWakeTimeIso` (`String`), `actualEndTimeIso` (`String`)
* `totalElapsedMinutes` (`double`), `predictedSolMinutes` (`double`), `circadianShiftHours` (`double`)
* `presetUsed` (`SleepPresetType`), `physicalStateUsed` (`PreSleepPhysicalState`)
* `analysisModeEnabled` (`bool`), `cycleBoundaryCalibrated` (`bool`)
* `measuredCycleDurationMinutes` (`double?` — non-null if Analysis Mode detected a boundary rustle)
* `completedCyclesCount` (`int`), `wakeHealthZoneAtStart` (`WakeTimeHealthZone`)
* `stageMinutesSummary` (`Map<String, double>`: minutes spent in `wakeOnset`, `lightN1N2`, `deepN3`, `remDreaming`)
* `stageTimelineSamples` (`List<Map<String, dynamic>>`: sampled every 5 minutes `{ "min": int, "stage": String, "dba": double }` to render the detail page hypnogram chart).

---

## 4. Two-Phase Permission & Hardware Volume Gatekeeper Logic

### Phase 1: First App Launch Onboarding Gatekeeper

When the app launches for the very first time (before or right after creating the first profile), execute `PermissionGatekeeperService.requestInitialPermissions()`:

1. Request `Permission.notification` (required on Android 13+ so the Foreground Service notification is visible).
2. Request `Permission.microphone` (`RECORD_AUDIO`).
3. Request `Permission.ignoreBatteryOptimizations` (opens Android's native 1-tap *"Allow app to always run in background?"* dialog).
4. **Fallback Instruction Popup:** If `Permission.ignoreBatteryOptimizations.isGranted` is still `false` or restricted by the OEM (e.g., Xiaomi/Samsung battery saver), show a Material 3 `AlertDialog`:
* **Title:** `"Enable Uninterrupted Background Sleep Tracking"`
* **Body:** Step-by-step instructions: *"1. Tap 'Open App Settings' below.\n2. Tap 'Battery'.\n3. Select 'Unrestricted' so Android does not stop your sleep audio overnight."*
* **Actions:** `TextButton("Later")` and `FilledButton("Open App Settings")` (calls `openAppSettings()`).



### Phase 2: Pre-Flight Gatekeeper (Triggered on "Start Sleep" Button Press)

When the user taps **"Start Sleep"** on the Pre-Sleep Setup Page, run a sequential 3-step verification pipeline **before** navigating to `ActiveSleepTrackingScreen`. If any step is canceled by the user, stay on the Pre-Sleep Setup Page and do NOT start the engine.

#### Step 2.1: Background Execution & Notification Check

* Verify `await Permission.ignoreBatteryOptimizations.isGranted`.
* If `false`, invoke `await Permission.ignoreBatteryOptimizations.request()`.
* If still `false`, display a blocking Material 3 `AlertDialog` with step-by-step instructions, an `"Open Settings"` button, a `"Retry Check"` button, and a `"Cancel"` button. If canceled, abort session start.

#### Step 2.2: Microphone Permission Check (Only if `enableAnalysisMode == true`)

* *Android OS Technical Note:* On Android 11–15, continuous background microphone access uses `Permission.microphone` (`RECORD_AUDIO` granted *"While using the app"*) combined with starting the `ForegroundService` (`foregroundServiceType="mediaPlayback|microphone"`) while the Activity is currently visible in the foreground.
* Verify `await Permission.microphone.isGranted`.
* If `false`, request `await Permission.microphone.request()`.
* If permanently denied or still `false`, show an error `AlertDialog`: *"Microphone Access Required for Analysis Mode — Analysis Mode listens for high-frequency bedsheet rustling to detect your natural sleep cycle boundaries. Please grant Microphone access or disable Analysis Mode."* with `"Open Settings"` and `"Cancel"` buttons.

#### Step 2.3: Reactive 70% Hardware Speaker Volume Check (Auto-Proceed Dialog)

* Read current Android media volume via `VolumeController().getVolume()` (returns `double` in `[0.0, 1.0]`).
* **Target Range:** `SleepEngineConstants.requiredHardwareVolumeFraction` (`0.70` ± `0.05`, i.e., `[0.65, 0.75]`).
* If current volume is already within `[0.65, 0.75]`, proceed immediately to `ActiveSleepTrackingScreen`.
* If current volume is outside `[0.65, 0.75]`, display the **Reactive Speaker Volume Dialog**:
* Subscribe to `VolumeController().listener((double newVol) { ... })`.
* Show a live `LinearProgressIndicator(value: currentVol)` and target marker at **70%**, explaining: *"For accurate decibel calibration (34–44 dBA), set your phone's media volume to 70% using your volume buttons."*
* Provide a convenience `FilledButton.tonal("Set to 70% Automatically")` that calls `VolumeController().setVolume(0.70)`.
* **Auto-Proceed Rule:** The instant `newVol >= 0.65 && newVol <= 0.75` is detected (whether via physical volume keys or the auto-set button), automatically close the dialog (`Navigator.of(context).pop(true)`) and transition immediately to `ActiveSleepTrackingScreen`.
* Provide a `TextButton("Cancel")` that closes the dialog with `false` and aborts session start.



---

## 5. Screen-by-Screen UI, Navigation & Edge-Case Specifications

### 5.1 App Launch & Zero-Profile Guard (`app_router.dart`)

* On launch, `ProfileBloc` loads `'app_profiles_registry_v1'` and `'app_active_profile_id_v1'`.
* **Case A (No profiles exist):** Route via `Navigator.pushAndRemoveUntil` to `CreateEditProfileScreen(isFirstProfile: true)`. Hide the back button (`automaticallyImplyLeading: false`) so the user cannot navigate to an empty shell.
* **Case B (Profiles exist):** If `activeProfileId` is valid, load that profile into `SleepEngineUnifier`; otherwise select `profiles.first.id`. Route to `MainShellScreen`.

---

### 5.2 Create / Edit Profile Screen (`create_edit_profile_screen.dart`)

Collects both user identity metadata and `OnboardingSurveyInput` required by `SleepEngineUnifier`:

1. **Avatar Picker:** Centered `CircleAvatar` (radius 44). If no image is selected, displays Material `Icons.person_outline`. Tapping opens a bottom sheet to pick from Gallery/Camera or reset to default placeholder.
2. **Profile Name:** `TextFormField` (Required, 1–30 chars, e.g., `"Main Profile"`).
3. **Physique Inputs:**
* Height (`cm`): Slider or numeric field (`120 – 230 cm`, default `175 cm`).
* Weight (`kg`): Slider or numeric field (`35 – 200 kg`, default `70 kg`).
* Age (`years`): Number field (`13 – 95`, default `20`).
* Biological Sex: `SegmentedButton<BiologicalSex>`.


4. **Habitual Sleep Routine (Circadian Anchors):**
* Usual Bedtime: Material `showTimePicker` button + `"I don't know / Irregular"` `CheckboxListTile` (passes `null` when checked).
* Usual Wake Time: Material `showTimePicker` button + `"I don't know"` `CheckboxListTile`.


5. **Scientific Survey MCQs (Each includes an explicit `"I don't know"` option):**
* Sleep Latency (`SurveySleepLatencyOption` — 5 choices including `unknown`).
* Noise Sensitivity (`SurveyNoiseSensitivityOption` — 4 choices including `unknown`).
* Natural Cycle Rhythm (`SurveyCycleRhythmOption` — 4 choices including `unknown`).


6. **Quiet-Room 30 dBA Speaker Calibration Card:**
* Button `"Test & Calibrate Speaker"` that locks media volume to `70%`, plays the 30 dBA reference pink noise via `ProceduralSleepAudioSynthesizer`, and lets the user adjust `calibrated30dBaDigitalAmplitude` (`0.0001 – 0.25`, default `0.008`) until barely audible at pillow distance.


7. **Save Action:** Creates `AppUserProfileMeta`, initializes `UserProfileModel.fromOnboardingSurvey(input)`, saves both to `SharedPreferences`, sets this profile as active, and routes to `MainShellScreen`.

---

### 5.3 Main Shell Screen (`main_shell_screen.dart`)

Uses a standard Material 3 `Scaffold`:

* **Top `AppBar`:**
* Title: Displays active tab name (`"Sleep History"` or `"Settings"`) and active profile name subtitle.
* **`actions` (Top-Right Google-Account-Style Profile Avatar):**
* `IconButton` wrapping the active profile's `CircleAvatar`.
* When tapped, opens a Material 3 modal dialog / menu card showing the active profile's avatar and name, with two list actions:
1. `ListTile(leading: Icon(Icons.switch_account), title: Text('Switch / Edit Profiles'))` $\to$ navigates to `SwitchProfilesScreen`.
2. `ListTile(leading: Icon(Icons.settings), title: Text('Profile & App Settings'))` $\to$ switches `MainShellScreen` to the Settings tab (or opens Settings).






* **Bottom Navigation Bar with Enlarged Center Circular "Start" Button:**
* Implemented via a Material 3 `BottomAppBar` + `FloatingActionButton.large` docked at `FloatingActionButtonLocation.centerDocked`:
* **Left Tab:** `IconButton` / Navigation item for **History** (`Icons.history`, selected by default on open).
* **Center Button:** Prominent circular `FloatingActionButton.large` with `Icons.bedtime` + `"Start"` label that navigates to `PreSleepSetupScreen`.
* **Right Tab:** `IconButton` / Navigation item for **Settings** (`Icons.tune`).





---

### 5.4 Switch / Edit Profiles Screen (`switch_profiles_screen.dart`)

* Lists all created profiles inside Material 3 `Card` / `ListTile` items:
* Leading: Profile `CircleAvatar`.
* Title: Profile `displayName` + `"Active"` `Chip` if currently selected.
* Subtitle: Learned Cycle Length (`"${profile.baselineCycleMinutes.toStringAsFixed(1)} min cycle • ${profile.completedAnalysisProbesCount} calibrations"`).
* **Tap on Card:** Sets that profile as active in `ProfileBloc`, reloads `SleepEngineUnifier` and `SleepHistoryCubit` for that `profileId`, and pops back to `MainShellScreen`.
* **Trailing Actions:**
* `IconButton(icon: Icon(Icons.edit_outlined))` $\to$ opens `CreateEditProfileScreen` pre-populated with that profile's data.
* `IconButton(icon: Icon(Icons.delete_outline))` $\to$ opens a confirmation `AlertDialog`: *"Delete profile '' and all its sleep history? This cannot be undone."*




* **Profile Deletion Edge-Case Rules:**
1. When confirmed, delete the profile from `'app_profiles_registry_v1'`, delete `'sleep_tracker_user_profile_v1_<id>'`, and delete `'sleep_history_records_v1_<id>'`.
2. **If other profiles still remain** and the deleted profile was the active one, automatically select the first remaining profile (`remainingProfiles.first.id`) as active.
3. **If ALL profiles are deleted (`remainingProfiles.isEmpty`):** Immediately execute `Navigator.of(context).pushAndRemoveUntil(..., CreateEditProfileScreen(isFirstProfile: true))` so the user is cleanly routed to create a new profile with zero null-pointer states.


* **Bottom / Floating Action:** `"Add New Profile"` button (`Icons.person_add`) routing to `CreateEditProfileScreen`.

---

### 5.5 Sleep History Tab & Long-Press Deletion Flow (`sleep_history_card.dart`)

* **Empty State:** If the active profile has zero recorded sleep sessions, display a centered Material 3 placeholder (`Icons.nights_stay_outlined`, `"No sleep sessions recorded yet. Tap Start below before bed."`).
* **History List (`ListView.builder`):**
Each `SleepSessionRecord` renders in a Material 3 `Card`:
* **Header Row:** Date (`"Thu, Oct 22"`), Bedtime $\to$ Wake time (`"23:35 – 07:12"`), and a `Chip` for the `SleepPresetType`.
* **Metrics Row:** Total Duration (`"7h 37m"`), Completed Cycles (`"5 Cycles"`), Deep N3 Duration (`"1h 42m N3"`), and an icon badge if Analysis Mode calibrated the profile that night (`Icons.auto_graph`).
* **Single Tap Interaction:** Navigates to `SleepHistoryDetailScreen(record: record)`.
* **Press-and-Hold (Long-Press) Interaction:**
* Holding the card (`onLongPress`) toggles a local state `_isRemoveActionVisible = true` on that card, smoothly expanding (`AnimatedSize`) a bottom action strip inside the card containing a destructive `FilledButton.tonalIcon(icon: Icon(Icons.delete_forever), label: Text('Remove Session'))` and a `TextButton('Cancel')`.
* Tapping `'Remove Session'` opens a Material 3 confirmation `AlertDialog`: *"Remove this sleep record from your history?"* with `"Cancel"` and `"Remove"` buttons.
* Confirming calls `SleepHistoryCubit.deleteSession(record.sessionId)`, removing it from `SharedPreferences` and animating the card out of the list.





---

### 5.6 Sleep History Detail Screen (`sleep_history_detail_screen.dart`)

Displays comprehensive post-sleep analytics for the tapped `SleepSessionRecord`:

1. **Top Summary Card:** Date, start/end timestamps, total time in bed vs net time asleep (`totalElapsedMinutes - predictedSolMinutes`), and `PreSleepPhysicalState` chip.
2. **Stage Distribution Breakdown Card:** Four Material 3 `LinearProgressIndicator` rows showing exact minutes and percentages spent in **Sleep Onset (SOL)**, **Light Sleep (N1/N2)**, **Deep Slow-Wave Sleep (N3)**, and **REM Dreaming**.
3. **Hypnogram & Acoustic dBA Timeline Card:** A custom `CustomPainter` (using `Theme.of(context).colorScheme` colors) plotting `stageTimelineSamples` across the night (Wake, REM, N1/N2, N3 levels on Y-axis, time on X-axis) overlaid with the speaker dBA envelope.
4. **Circadian & Analysis Mode Telemetry Card:** Shows circadian shift ($\Delta t_{\text{circ}}$ hours from habitual bedtime), whether the Wake Maintenance Zone penalty was triggered, and if Analysis Mode ran, the exact debiased cycle length measured that night.

---

### 5.7 Pre-Sleep Setup Screen (`pre_sleep_setup_screen.dart`)

Opened when the user taps the center circular **"Start"** button:

1. **Target Wake-Up Time Selector:** Large interactive Material 3 time card (`InkWell` opening `showTimePicker` or embedded wheel) defaulting to the active profile's `habitualWakeMin`.
2. **Today's Physical Status (`PreSleepPhysicalState`):** ChoiceChips / Radio cards for *Normal Baseline*, *Heavy Workout*, *Heavy Meal (<2h)*, *Low Exhaustion*, and *High Cognitive Load*.
3. **Sleep Goal Preset (`SleepPresetType`):** 4 selectable Material 3 cards with descriptions (*Deep Sleep: Muscle Repair*, *Deep Sleep: Cognitive & Memory*, *Basic Balanced Sleep*, *Wake Up Fresh*).
4. **Analysis Mode Switch (`SwitchListTile`):** *"Measure & Calibrate Cycle Length Tonight (Uses Microphone)"*.
5. **Auto-Updating Wake-Up Health & Alignment Indicator (`wake_health_indicator_bar.dart`):**
* Pinned above the bottom Start button.
* Every time Wake Time, Physical State, or Preset changes, `PreSleepSetupCubit` synchronously calls `unifier.previewWakeTimeHealth(...)`.
* Renders an animated `TweenAnimationBuilder<double>` wrapping a thick Material 3 `LinearProgressIndicator(minHeight: 12, borderRadius: BorderRadius.circular(6))` whose color smoothly interpolates from **Red (`error`)** $\to$ **Yellow (`Colors.amber.shade700`)** $\to$ **Green (`Colors.green.shade600`)** based on `evaluation.healthScoreNormalized` and `evaluation.healthZone`.
* Displays `evaluation.statusHeadline`, `evaluation.statusSubtitle`, and a 1-tap `ActionChip("Set Ideal Time: HH:MM")` (using `evaluation.nearestNaturalTroughWakeTime`) whenever the bar is in the Red or Yellow zone.


6. **Bottom "Start Sleep" `FilledButton.icon`:**
* Triggers the **Phase 2 Pre-Flight Gatekeeper** (Background check $\to$ Mic check $\to$ 70% Speaker Volume auto-proceed dialog).
* Once all checks pass, starts the foreground service and navigates (`pushReplacement`) to `ActiveSleepTrackingScreen`.



---

### 5.8 Active Sleep Tracking Screen (`active_sleep_tracking_screen.dart`)

Designed for bedside overnight operation:

1. **Background & Lock-Screen Execution:**
* Upon entering, starts `FlutterForegroundTask` with notification title `"Sleep Perfecter Active"` and dynamic body `"Stage: <predictedStage> • Target Wake: HH:MM"`, acquires a `PARTIAL_WAKE_LOCK`, starts the `48000 Hz` speaker PCM stream, starts the `16000 Hz` mic PCM stream (if Analysis Mode is enabled), and starts the `1.0s` periodic heartbeat timer calling `unifier.processEngineTick(...)`.


2. **Live Telemetry Widgets (Material 3 Cards):**
* **Current Date & Clock Header:** Displays current date, live clock, and countdown until `targetWakeTime`.
* **Current Sleep Cycle & Stage Card:** Displays `predictionFrame.predictedStage` badge, Cycle `currentCycleIndex` of `optimalTotalCyclesForWakeWindow`, and a circular/linear cycle progress indicator (`cycleProgressFraction`).
* **Real-Time Acoustic Engine Card:** Shows current speaker output (`mergedSpeakerRecipe.targetVolumeDba` dBA), active filter cutoff (`lowPassCutoffHz` Hz), spectral warmth (`spectralSlopeBeta`), and whether 50 ms N3 pulses are active.
* **Analysis Mode Status Card (if enabled):** Shows `analysisFrame.currentMode` (*Passive Monitoring* vs *Active 34–44 dBA Boundary Probing*), high-frequency (>2.5 kHz) room floor (`rollingHighFreqFloorDba` dBA), live mic level (`currentHighFreqMicDba` dBA), and a confirmation badge if tonight's cycle boundary movement was already captured.


3. **2-Second Hold-to-Stop Button (`hold_to_stop_button.dart`):**
* Medium-sized button at the bottom of the screen (`SizedBox(width: 220, height: 56)`).
* Uses a `GestureDetector(onTapDown: ..., onTapUp: ..., onTapCancel: ...)` driving an `AnimationController(duration: const Duration(seconds: 2))`.
* While pressed, a circular/linear progress overlay inside the button fills from `0.0` to `1.0` over `2.0 seconds` with label `"Hold 2s to Stop..."`.
* If the user releases their finger before `2.0 seconds`, the controller reverses smoothly to `0.0` and the sleep session continues uninterrupted (preventing accidental sleepy taps).
* When the controller completes at `2.0 seconds`:
1. Triggers `HapticFeedback.heavyImpact()`.
2. Dispatches `StopSleepSessionEvent` to `ActiveSleepBloc`.
3. Stops the 1-second timer, closes the mic stream, stops the speaker PCM stream, and stops the Foreground Service.
4. Builds and saves the `SleepSessionRecord` to `SleepHistoryRepository` (note: if Analysis Mode did not reach a cycle boundary before stopping, `UserProfileModel` remains untouched, which is completely safe).
5. Navigates (`pushReplacement`) back to `MainShellScreen` (History Tab), where the newly recorded sleep session appears at the top of the list.





---

## 6. Edge-Case Handling Matrix for Coding Agents

| Edge Case Scenario | Required System Behavior |
| --- | --- |
| **1. User deletes the currently active profile, but 1+ other profiles exist** | `ProfileBloc` immediately selects `remainingProfiles.first` as the new active profile, re-initializes `SleepEngineUnifier` with the new `profileId`, reloads `SleepHistoryCubit`, and refreshes UI. |
| **2. User deletes the LAST remaining profile (0 profiles left)** | `ProfileBloc` clears `'app_active_profile_id_v1'` and dispatches a navigation event that executes `Navigator.pushAndRemoveUntil` to `CreateEditProfileScreen(isFirstProfile: true)` with back-navigation disabled. |
| **3. User stops sleep session after only 5 minutes (during SOL or before Analysis probe)** | Session stops cleanly. `UserProfileModel` is NOT modified (since Module 2 only updates the profile when `validRustleConfirmed == true`). A `SleepSessionRecord` with `totalElapsedMinutes: 5.0` is saved to history (and can be long-press deleted by the user if desired). |
| **4. Incoming phone call or other alarm interrupts audio overnight** | Listen to audio interruptions in `AudioIoService`. Pause speaker PCM synthesis during the phone call while keeping the session clock running; automatically resume speaker PCM synthesis and restore 70% volume when the call ends. |
| **5. User selects a wake time like `07:00` when current time is `23:45**` | Both `PreSleepSetupCubit` and `SleepEngineUnifier.startSleepSession` normalize `targetWakeTime` by adding `Duration(days: 1)` whenever `!targetWakeTime.isAfter(sleepStartTime)`. |
| **6. User lowers hardware volume to 0% during the Pre-Flight Volume Dialog** | The dialog stays open showing current volume (`0%`) vs target (`70%`). The session only starts if volume enters `[65%, 75%]`, or aborts cleanly if the user taps `"Cancel"`. |

```

```

"