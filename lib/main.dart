import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/sleep_core_engine.dart';
import 'data/adapters/shared_prefs_sleep_adapter.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/sleep_history_repository.dart';
import 'logic/active_sleep_bloc/active_sleep_bloc.dart';
import 'logic/profile_bloc/profile_bloc.dart';
import 'logic/profile_bloc/profile_event.dart';
import 'logic/sleep_history_cubit/sleep_history_cubit.dart';
import 'presentation/app_router.dart';
import 'services/audio_io_service.dart';
import 'services/permission_gatekeeper_service.dart';
import 'services/sleep_foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. SharedPreferences Initialization
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // 2. Phase 1: Request initial onboarding permissions (Mic, Notif, Battery)
  await PermissionGatekeeperService.requestInitialPermissions();

  // 3. Infrastructure & Services
  final storageAdapter = SharedPrefsSleepAdapter(prefs);
  final unifier = SleepEngineUnifier(storageAdapter: storageAdapter);
  final profileRepository = ProfileRepository(prefs);
  final sleepHistoryRepository = SleepHistoryRepository(prefs);
  final audioHardwareService = DefaultAudioHardwareService();
  final backgroundService = FlutterForegroundTaskBackgroundService();
  await backgroundService.init();

  runApp(SleepPerfecterApp(
    profileRepository: profileRepository,
    sleepHistoryRepository: sleepHistoryRepository,
    unifier: unifier,
    audioHardwareService: audioHardwareService,
    backgroundService: backgroundService,
  ));
}

class SleepPerfecterApp extends StatelessWidget {
  final ProfileRepository profileRepository;
  final SleepHistoryRepository sleepHistoryRepository;
  final SleepEngineUnifier unifier;
  final AudioHardwareService audioHardwareService;
  final BackgroundExecutionService backgroundService;

  const SleepPerfecterApp({
    super.key,
    required this.profileRepository,
    required this.sleepHistoryRepository,
    required this.unifier,
    required this.audioHardwareService,
    required this.backgroundService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProfileRepository>.value(value: profileRepository),
        RepositoryProvider<SleepHistoryRepository>.value(
            value: sleepHistoryRepository),
        RepositoryProvider<AudioHardwareService>.value(
            value: audioHardwareService),
        RepositoryProvider<SleepEngineUnifier>.value(value: unifier),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ProfileBloc>(
            create: (_) => ProfileBloc(
              repository: profileRepository,
              unifier: unifier,
            )..add(const LoadProfilesEvent()),
          ),
          BlocProvider<SleepHistoryCubit>(
            create: (_) =>
                SleepHistoryCubit(repository: sleepHistoryRepository),
          ),
          BlocProvider<ActiveSleepBloc>(
            create: (_) => ActiveSleepBloc(
              unifier: unifier,
              sleepHistoryRepository: sleepHistoryRepository,
              audioHardwareService: audioHardwareService,
              backgroundService: backgroundService,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Sleep Perfecter',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: false),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: false),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: ThemeMode.system,
          home: const AppRouter(),
        ),
      ),
    );
  }
}

