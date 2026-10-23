import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/active_sleep_bloc/active_sleep_bloc.dart';
import '../logic/active_sleep_bloc/active_sleep_state.dart';
import '../logic/profile_bloc/profile_bloc.dart';
import '../logic/profile_bloc/profile_state.dart';
import 'screens/active_sleep_tracking_screen.dart';
import 'screens/create_edit_profile_screen.dart';
import 'screens/main_shell_screen.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileZeroProfiles) {
          // Zero profiles registered: force user to create first profile
          return const CreateEditProfileScreen(isFirstProfile: true);
        } else if (state is ProfileLoaded) {
          // Check if an active overnight sleep session is already running
          return BlocBuilder<ActiveSleepBloc, ActiveSleepState>(
            builder: (context, activeSleepState) {
              if (activeSleepState is ActiveSleepRunning) {
                return ActiveSleepTrackingScreen(
                  activeProfile: state.activeProfile,
                );
              }
              return const MainShellScreen();
            },
          );
        } else if (state is ProfileError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Profile Error',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Loading or initial state
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
