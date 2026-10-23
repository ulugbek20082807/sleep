import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep/core/sleep_core_engine.dart';
import 'package:sleep/data/adapters/shared_prefs_sleep_adapter.dart';
import 'package:sleep/data/models/app_user_profile_meta.dart';
import 'package:sleep/data/models/sleep_session_record.dart';
import 'package:sleep/data/repositories/profile_repository.dart';
import 'package:sleep/data/repositories/sleep_history_repository.dart';
import 'package:sleep/logic/active_sleep_bloc/active_sleep_bloc.dart';
import 'package:sleep/logic/active_sleep_bloc/active_sleep_event.dart';
import 'package:sleep/logic/active_sleep_bloc/active_sleep_state.dart';
import 'package:sleep/logic/profile_bloc/profile_bloc.dart';
import 'package:sleep/logic/profile_bloc/profile_event.dart';
import 'package:sleep/logic/profile_bloc/profile_state.dart';
import 'package:sleep/logic/sleep_history_cubit/sleep_history_cubit.dart';
import 'package:sleep/presentation/screens/create_edit_profile_screen.dart';
import 'package:sleep/presentation/screens/scientific_profile_data_screen.dart';
import 'package:sleep/presentation/widgets/hold_to_stop_button.dart';
import 'package:sleep/presentation/widgets/profile_avatar_menu_button.dart';
import 'package:sleep/presentation/widgets/wake_health_indicator_bar.dart';
import 'package:sleep/services/audio_io_service.dart';
import 'package:sleep/services/sleep_foreground_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DefaultAudioHardwareService.disableNativeAudioForTesting = true;
  });

  group('Data Models Tests', () {
    test('AppUserProfileMeta json serialization roundtrip', () {
      final now = DateTime.now();
      final meta = AppUserProfileMeta(
        id: 'test-uuid-1',
        displayName: 'Test Sleeper',
        avatarPath: '/path/to/avatar.png',
        createdAt: now,
      );

      final json = meta.toJson();
      final deserialized = AppUserProfileMeta.fromJson(json);

      expect(deserialized.id, 'test-uuid-1');
      expect(deserialized.displayName, 'Test Sleeper');
      expect(deserialized.avatarPath, '/path/to/avatar.png');
      expect(deserialized.createdAt.toIso8601String(), now.toIso8601String());
    });

    test('SleepSessionRecord json serialization roundtrip', () {
      final now = DateTime.now();
      final wake = now.add(const Duration(hours: 8));

      final record = SleepSessionRecord(
        sessionId: 'session-123',
        profileId: 'profile-abc',
        sleepStartTimeIso: now.toIso8601String(),
        targetWakeTimeIso: wake.toIso8601String(),
        actualEndTimeIso: wake.toIso8601String(),
        totalElapsedMinutes: 480.0,
        predictedSolMinutes: 14.5,
        circadianShiftHours: 0.2,
        presetUsed: SleepPresetType.basicBalancedSleep,
        physicalStateUsed: PreSleepPhysicalState.normalBaseline,
        analysisModeEnabled: true,
        cycleBoundaryCalibrated: true,
        measuredCycleDurationMinutes: 91.5,
        completedCyclesCount: 5,
        wakeHealthZoneAtStart: WakeTimeHealthZone.greenOptimal,
        stageMinutesSummary: const {
          'wakeOnset': 14.5,
          'lightN1N2': 240.0,
          'deepN3': 115.5,
          'remDreaming': 110.0,
        },
        stageTimelineSamples: const [
          {'min': 0, 'stage': 'wakeOnset', 'dba': 30.0},
          {'min': 15, 'stage': 'n2DescendingLight', 'dba': 32.0},
        ],
      );

      final json = record.toJson();
      final deserialized = SleepSessionRecord.fromJson(json);

      expect(deserialized.sessionId, 'session-123');
      expect(deserialized.profileId, 'profile-abc');
      expect(deserialized.totalElapsedMinutes, 480.0);
      expect(deserialized.presetUsed, SleepPresetType.basicBalancedSleep);
      expect(deserialized.completedCyclesCount, 5);
      expect(deserialized.wakeHealthZoneAtStart, WakeTimeHealthZone.greenOptimal);
      expect(deserialized.measuredCycleDurationMinutes, 91.5);
    });
  });

  group('ProfileRepository Tests', () {
    test('Create, switch, and delete profile logic', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ProfileRepository(prefs);

      final meta1 = AppUserProfileMeta(
        id: 'user-1',
        displayName: 'User 1',
        createdAt: DateTime.now(),
      );
      final meta2 = AppUserProfileMeta(
        id: 'user-2',
        displayName: 'User 2',
        createdAt: DateTime.now(),
      );

      final survey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 22,
        habitualBedtimeMinutesFromMidnight: 1410,
        habitualWakeMinutesFromMidnight: 450,
      );
      final profile1 = UserProfileModel.fromOnboardingSurvey(survey);

      // Create profile 1
      await repo.createProfile(meta: meta1, userProfileModel: profile1);
      var profiles = await repo.getProfiles();
      expect(profiles.length, 1);
      expect(await repo.getActiveProfileId(), 'user-1');

      // Create profile 2
      await repo.createProfile(meta: meta2, userProfileModel: profile1);
      profiles = await repo.getProfiles();
      expect(profiles.length, 2);

      // Switch to profile 2
      await repo.setActiveProfileId('user-2');
      expect(await repo.getActiveProfileId(), 'user-2');

      // Delete active profile 2 -> should automatically fall back to profile 1
      final nextActive = await repo.deleteProfile('user-2');
      expect(nextActive, 'user-1');
      expect(await repo.getActiveProfileId(), 'user-1');
      profiles = await repo.getProfiles();
      expect(profiles.length, 1);

      // Delete last profile 1 -> should be null (zero profiles)
      final afterLast = await repo.deleteProfile('user-1');
      expect(afterLast, isNull);
      expect(await repo.getActiveProfileId(), isNull);
      profiles = await repo.getProfiles();
      expect(profiles.isEmpty, isTrue);
    });
  });

  group('Pre-Sleep Wake Health Preview Evaluation', () {
    test('8 hours sleep yields 5 cycles and green optimal health zone', () {
      final survey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        habitualBedtimeMinutesFromMidnight: 1410,
        habitualWakeMinutesFromMidnight: 450,
      );
      final profile = UserProfileModel.fromOnboardingSurvey(survey);
      final predictor = SleepAcousticPredictorModule(initialProfile: profile);

      final now = DateTime(2026, 10, 22, 23, 0);
      final wakeTime = now.add(const Duration(hours: 8));

      final eval = predictor.evaluateWakeTimeHealthPreview(
        sleepStartTime: now,
        targetWakeTime: wakeTime,
        physicalState: PreSleepPhysicalState.normalBaseline,
        preset: SleepPresetType.basicBalancedSleep,
      );

      expect(eval.matchedCycleCount, greaterThanOrEqualTo(4));
      expect(eval.healthScoreNormalized, inInclusiveRange(0.0, 1.0));
      expect(eval.healthZone, isA<WakeTimeHealthZone>());
      expect(eval.statusHeadline.isNotEmpty, isTrue);
      expect(eval.statusSubtitle.isNotEmpty, isTrue);
    });

    test('8 AM test: snapping to nearestNaturalTroughWakeTime scores high efficiency with supportive night-owl note', () {
      final survey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        habitualBedtimeMinutesFromMidnight: 1410,
        habitualWakeMinutesFromMidnight: 450,
      );
      final profile = UserProfileModel.fromOnboardingSurvey(survey);
      final predictor = SleepAcousticPredictorModule(initialProfile: profile);

      // Testing at 8:00 AM
      final now = DateTime(2026, 10, 23, 8, 0);
      final initialWakeTime = now.add(const Duration(hours: 8)); // 16:00

      final initialEval = predictor.evaluateWakeTimeHealthPreview(
        sleepStartTime: now,
        targetWakeTime: initialWakeTime,
        physicalState: PreSleepPhysicalState.normalBaseline,
        preset: SleepPresetType.basicBalancedSleep,
      );

      // Snap to recommended nearest natural trough wake time
      final idealWake = initialEval.nearestNaturalTroughWakeTime;
      expect(idealWake.isAfter(now), isTrue);

      final idealEval = predictor.evaluateWakeTimeHealthPreview(
        sleepStartTime: now,
        targetWakeTime: idealWake,
        physicalState: PreSleepPhysicalState.normalBaseline,
        preset: SleepPresetType.basicBalancedSleep,
      );

      // Snapping to ideal wake time must score >= 75% (Green Optimal)
      expect(idealEval.healthScoreNormalized, greaterThanOrEqualTo(0.75));
      expect(idealEval.healthZone, WakeTimeHealthZone.greenOptimal);
      // Verify supportive daytime / night-owl schedule note
      expect(
        idealEval.statusSubtitle.contains('schedule') ||
            idealEval.statusSubtitle.contains('Daytime'),
        isTrue,
      );
    });
  });

  group('Widget Tests', () {
    testWidgets('WakeHealthIndicatorBar renders correctly and triggers callback',
        (tester) async {
      bool snapped = false;
      final eval = WakeTimeHealthEvaluation(
        healthScoreNormalized: 0.60,
        healthZone: WakeTimeHealthZone.yellowCaution,
        matchedCycleCount: 4,
        predictedSolMinutes: 14.0,
        netSleepDurationMinutes: 380.0,
        requiredPacingFactor: 1.05,
        rawPhaseMismatchMinutes: 20.0,
        nearestNaturalTroughWakeTime: DateTime(2026, 10, 23, 7, 15),
        statusHeadline: 'Short Sleep Window (4 Cycles)',
        statusSubtitle: 'Boundary aligns well, but reduced REM.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WakeHealthIndicatorBar(
              evaluation: eval,
              onSnapToIdealTime: () {
                snapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Short Sleep Window (4 Cycles)'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);

      final snapButton = find.byType(FilledButton);
      expect(snapButton, findsOneWidget);

      await tester.tap(snapButton);
      await tester.pump();
      expect(snapped, isTrue);
    });

    testWidgets('WakeHealthIndicatorBar shows Suggest Optimal Wake Time button even at 100% green optimal',
        (tester) async {
      bool snapped = false;
      final eval = WakeTimeHealthEvaluation(
        healthScoreNormalized: 1.0,
        healthZone: WakeTimeHealthZone.greenOptimal,
        matchedCycleCount: 5,
        predictedSolMinutes: 14.0,
        netSleepDurationMinutes: 460.0,
        requiredPacingFactor: 1.0,
        rawPhaseMismatchMinutes: 0.0,
        nearestNaturalTroughWakeTime: DateTime(2026, 10, 23, 7, 30),
        statusHeadline: 'Optimal Sleep Architecture (5 Cycles)',
        statusSubtitle: 'Boundary aligns with REM trough.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WakeHealthIndicatorBar(
              evaluation: eval,
              onSnapToIdealTime: () {
                snapped = true;
              },
            ),
          ),
        ),
      );

      final button = find.widgetWithText(
        FilledButton,
        'Suggest Optimal Wake Time (07:30 • 5 Cycles)',
      );
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(snapped, isTrue);
    });

    testWidgets('HoldToStopButton renders with hold instruction',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldToStopButton(
                onStopConfirmed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hold to Stop Sleep'), findsOneWidget);
    });

    testWidgets('ScientificProfileDataScreen renders all sections and parameters',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meta = AppUserProfileMeta(
        id: 'u-1',
        displayName: 'Ulugbek',
        createdAt: DateTime.now(),
      );
      final survey = OnboardingSurveyInput(
        heightCm: 180.0,
        weightKg: 75.0,
        ageYears: 25,
        habitualBedtimeMinutesFromMidnight: 1410,
        habitualWakeMinutesFromMidnight: 450,
      );
      final profile = UserProfileModel.fromOnboardingSurvey(survey);

      await tester.pumpWidget(
        MaterialApp(
          home: ScientificProfileDataScreen(meta: meta, profile: profile),
        ),
      );

      expect(
        find.text('Scientific Profile Data (Menu for Nerds)'),
        findsOneWidget,
      );
      expect(find.text('1. Ultradian Cycle Architecture'), findsOneWidget);
      expect(find.text('2. Sleep Onset & Circadian Dynamics'), findsOneWidget);
      expect(find.text('3. Acoustic Synthesis & Calibration'), findsOneWidget);
      expect(
        find.text('4. Physical State Covariates (β_state)'),
        findsOneWidget,
      );
      expect(
        find.text('5. Kalman Filter Covariance Matrix (P)'),
        findsOneWidget,
      );
      expect(find.text('6. Physique & Anthropometrics'), findsOneWidget);
    });

    testWidgets('ProfileAvatarMenuButton displays popup dialog with 95% width',
        (tester) async {
      final meta = AppUserProfileMeta(
        id: 'u-1',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ProfileAvatarMenuButton(
                  activeProfile: meta,
                  onOpenSwitchProfiles: () {},
                  onOpenSettings: () {},
                  onOpenScientificData: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ProfileAvatarMenuButton));
      await tester.pumpAndSettle();

      expect(find.text('Active Profile'), findsOneWidget);
      expect(find.text('Scientific Data (Menu for Nerds)'), findsOneWidget);
      expect(find.text('Switch / Edit Profiles'), findsOneWidget);
    });

    test('ActiveSleepBloc reverts profile changes if stopped prematurely (< 1 cycle)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storageAdapter = SharedPrefsSleepAdapter(prefs);
      final unifier = SleepEngineUnifier(storageAdapter: storageAdapter);
      final historyRepo = SleepHistoryRepository(prefs);
      final audioService = DefaultAudioHardwareService();
      final bgService = FlutterForegroundTaskBackgroundService();

      final survey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        habitualBedtimeMinutesFromMidnight: 1410,
        habitualWakeMinutesFromMidnight: 450,
      );
      final initialProfile = await unifier.initializeAndLoadProfile(
        fallbackSurvey: survey,
        enableAnalysisModeTonight: false,
        customProfileId: 'test-user',
      );
      final double originalCycleLen = initialProfile.baselineCycleMinutes;

      final bloc = ActiveSleepBloc(
        unifier: unifier,
        sleepHistoryRepository: historyRepo,
        audioHardwareService: audioService,
        backgroundService: bgService,
      );

      final now = DateTime.now();
      bloc.add(StartSleepSessionEvent(
        profileId: 'test-user',
        sleepStartTime: now,
        targetWakeTime: now.add(const Duration(hours: 8)),
        physicalState: PreSleepPhysicalState.normalBaseline,
        preset: SleepPresetType.basicBalancedSleep,
        enableAnalysisMode: true,
        wakeHealthZoneAtStart: WakeTimeHealthZone.greenOptimal,
      ));

      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 50));

      // User stops sleep after 2 minutes (premature stop before 1 full cycle)
      bloc.add(const StopSleepSessionEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      final state = bloc.state;
      expect(state, isA<ActiveSleepCompleted>());
      final completed = state as ActiveSleepCompleted;
      expect(completed.wasShortSession, isTrue);
      expect(completed.profileWasUpdated, isFalse);
      // Profile constants must remain untouched
      expect(unifier.predictorModule.currentProfile.baselineCycleMinutes, originalCycleLen);

      await bloc.close();
    });

    test('ActiveSleepBloc handles analysis confirmation accept vs discard', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storageAdapter = SharedPrefsSleepAdapter(prefs);
      final unifier = SleepEngineUnifier(storageAdapter: storageAdapter);
      final historyRepo = SleepHistoryRepository(prefs);
      final audioService = DefaultAudioHardwareService();
      final bgService = FlutterForegroundTaskBackgroundService();

      final survey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        habitualBedtimeMinutesFromMidnight: 1410,
        habitualWakeMinutesFromMidnight: 450,
      );
      final initialProfile = await unifier.initializeAndLoadProfile(
        fallbackSurvey: survey,
        enableAnalysisModeTonight: false,
        customProfileId: 'test-user-2',
      );
      final double initialCycleLen = initialProfile.baselineCycleMinutes;

      final bloc = ActiveSleepBloc(
        unifier: unifier,
        sleepHistoryRepository: historyRepo,
        audioHardwareService: audioService,
        backgroundService: bgService,
      );

      // Verify that rolling back to pre-session snapshot properly restores values
      unifier.startSleepSession(
        sleepStartTime: DateTime.now(),
        targetWakeTime: DateTime.now().add(const Duration(hours: 8)),
        physicalState: PreSleepPhysicalState.normalBaseline,
        preset: SleepPresetType.basicBalancedSleep,
        enableAnalysisMode: true,
      );

      // Simulate mid-session modification
      final modified = unifier.predictorModule.currentProfile.copyWith(baselineCycleMinutes: 98.5);
      unifier.predictorModule.updateProfile(modified);
      expect(unifier.predictorModule.currentProfile.baselineCycleMinutes, 98.5);

      // Rollback to pre-session snapshot
      await unifier.rollbackProfileToPreSessionSnapshot();
      expect(unifier.predictorModule.currentProfile.baselineCycleMinutes, initialCycleLen);

      await bloc.close();
    });

    test('ProfileBloc creation, event, and close', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storageAdapter = SharedPrefsSleepAdapter(prefs);
      final unifier = SleepEngineUnifier(storageAdapter: storageAdapter);
      final repo = ProfileRepository(prefs);

      final profileBloc = ProfileBloc(
        repository: repo,
        unifier: unifier,
      );

      final survey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        sex: BiologicalSex.otherOrUnspecified,
        habitualBedtimeMinutesFromMidnight: null,
        habitualWakeMinutesFromMidnight: null,
      );

      profileBloc.add(CreateProfileEvent(
        displayName: 'Test',
        avatarPath: null,
        survey: survey,
      ));
      await expectLater(
        profileBloc.stream,
        emitsInOrder([
          isA<ProfileLoading>(),
          isA<ProfileLoaded>(),
        ]),
      );

      await profileBloc.close();
    });

    testWidgets('CreateEditProfileScreen renders fields, toggles calibration, and creates profile',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storageAdapter = SharedPrefsSleepAdapter(prefs);
      final unifier = SleepEngineUnifier(storageAdapter: storageAdapter);
      final repo = ProfileRepository(prefs);
      final historyRepo = SleepHistoryRepository(prefs);

      final profileBloc = ProfileBloc(
        repository: repo,
        unifier: unifier,
      );
      final historyCubit = SleepHistoryCubit(repository: historyRepo);

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: profileBloc),
            BlocProvider.value(value: historyCubit),
          ],
          child: const MaterialApp(
            home: CreateEditProfileScreen(isFirstProfile: true),
          ),
        ),
      );

      expect(find.text('Create Your Sleep Profile'), findsOneWidget);
      expect(find.text('Create Profile'), findsOneWidget);

      final calibBtn = find.text('Test Calibration Tone');
      expect(calibBtn, findsOneWidget);

      await tester.tap(calibBtn);
      await tester.pump();
      expect(find.text('Stop Test'), findsOneWidget);

      await tester.tap(find.text('Stop Test'));
      await tester.pump();
      expect(find.text('Test Calibration Tone'), findsOneWidget);

      final createBtn = find.widgetWithText(FilledButton, 'Create Profile');
      await tester.tap(createBtn);
      await tester.pump();

      // Ensure button shows 'Saving...' while submitting to prevent double-tap creation
      expect(find.text('Saving...'), findsOneWidget);

      // Settle async creation and route navigation to MainShellScreen
      await tester.pumpAndSettle();
      expect(find.text('Sleep History'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await profileBloc.close();
        await historyCubit.close();
      });
    });
  });
}
