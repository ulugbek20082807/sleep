import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';
import '../../data/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;
  final SleepEngineUnifier unifier;

  ProfileBloc({
    required this.repository,
    required this.unifier,
  }) : super(const ProfileInitial()) {
    on<LoadProfilesEvent>(_onLoadProfiles);
    on<CreateProfileEvent>(_onCreateProfile);
    on<SwitchProfileEvent>(_onSwitchProfile);
    on<EditProfileEvent>(_onEditProfile);
    on<DeleteProfileEvent>(_onDeleteProfile);
  }

  Future<void> _onLoadProfiles(
    LoadProfilesEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final profiles = await repository.getProfiles();
      if (profiles.isEmpty) {
        emit(const ProfileZeroProfiles());
        return;
      }

      String? activeId = await repository.getActiveProfileId();
      AppUserProfileMeta? activeMeta;

      if (activeId != null) {
        for (final p in profiles) {
          if (p.id == activeId) {
            activeMeta = p;
            break;
          }
        }
      }

      if (activeMeta == null) {
        activeMeta = profiles.first;
        activeId = activeMeta.id;
        await repository.setActiveProfileId(activeId);
      }

      final fallbackSurvey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        sex: BiologicalSex.otherOrUnspecified,
        habitualBedtimeMinutesFromMidnight: null,
        habitualWakeMinutesFromMidnight: null,
        latencyAnswer: SurveySleepLatencyOption.unknown,
        sensitivityAnswer: SurveyNoiseSensitivityOption.unknown,
        cycleRhythmAnswer: SurveyCycleRhythmOption.unknown,
      );

      final userProfile = await unifier.initializeAndLoadProfile(
        fallbackSurvey: fallbackSurvey,
        enableAnalysisModeTonight: false,
        customProfileId: activeId,
      );

      emit(ProfileLoaded(
        profiles: profiles,
        activeProfile: activeMeta,
        activeUserProfile: userProfile,
      ));
    } catch (e) {
      emit(ProfileError('Failed to load profiles: $e'));
    }
  }

  Future<void> _onCreateProfile(
    CreateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final newId = const Uuid().v4();
      final meta = AppUserProfileMeta(
        id: newId,
        displayName: event.displayName.trim().isEmpty
            ? 'Sleep Explorer'
            : event.displayName.trim(),
        avatarPath: event.avatarPath,
        createdAt: DateTime.now(),
      );

      final userProfile = await unifier.initializeAndLoadProfile(
        fallbackSurvey: event.survey,
        enableAnalysisModeTonight: false,
        customProfileId: newId,
      );

      await repository.createProfile(
        meta: meta,
        userProfileModel: userProfile,
      );
      await repository.setActiveProfileId(newId);

      final profiles = await repository.getProfiles();
      emit(ProfileLoaded(
        profiles: profiles,
        activeProfile: meta,
        activeUserProfile: userProfile,
      ));
    } catch (e) {
      emit(ProfileError('Failed to create profile: $e'));
    }
  }

  Future<void> _onSwitchProfile(
    SwitchProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final profiles = await repository.getProfiles();
      final targetMeta =
          profiles.firstWhere((p) => p.id == event.targetProfileId);

      await repository.setActiveProfileId(targetMeta.id);

      final fallbackSurvey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        sex: BiologicalSex.otherOrUnspecified,
        habitualBedtimeMinutesFromMidnight: null,
        habitualWakeMinutesFromMidnight: null,
        latencyAnswer: SurveySleepLatencyOption.unknown,
        sensitivityAnswer: SurveyNoiseSensitivityOption.unknown,
        cycleRhythmAnswer: SurveyCycleRhythmOption.unknown,
      );

      final userProfile = await unifier.initializeAndLoadProfile(
        fallbackSurvey: fallbackSurvey,
        enableAnalysisModeTonight: false,
        customProfileId: targetMeta.id,
      );

      emit(ProfileLoaded(
        profiles: profiles,
        activeProfile: targetMeta,
        activeUserProfile: userProfile,
      ));
    } catch (e) {
      emit(ProfileError('Failed to switch profile: $e'));
    }
  }

  Future<void> _onEditProfile(
    EditProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      await repository.updateProfile(
        meta: event.meta,
        userProfileModel: event.updatedUserProfile,
      );

      final currentState = state;
      if (currentState is ProfileLoaded &&
          currentState.activeProfile.id == event.meta.id) {
        if (event.updatedUserProfile != null) {
          await unifier.saveProfileToStorage(event.updatedUserProfile!);
          unifier.predictorModule.updateProfile(event.updatedUserProfile!);
        }

        final profiles = await repository.getProfiles();
        final updatedActive =
            profiles.firstWhere((p) => p.id == event.meta.id);
        emit(ProfileLoaded(
          profiles: profiles,
          activeProfile: updatedActive,
          activeUserProfile:
              event.updatedUserProfile ?? currentState.activeUserProfile,
        ));
      } else {
        final profiles = await repository.getProfiles();
        if (currentState is ProfileLoaded) {
          emit(ProfileLoaded(
            profiles: profiles,
            activeProfile: currentState.activeProfile,
            activeUserProfile: currentState.activeUserProfile,
          ));
        }
      }
    } catch (e) {
      emit(ProfileError('Failed to update profile: $e'));
    }
  }

  Future<void> _onDeleteProfile(
    DeleteProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final newActiveId = await repository.deleteProfile(event.profileId);
      final remaining = await repository.getProfiles();

      if (remaining.isEmpty) {
        emit(const ProfileZeroProfiles());
        return;
      }

      final activeMeta = remaining.firstWhere((p) => p.id == newActiveId,
          orElse: () => remaining.first);

      await repository.setActiveProfileId(activeMeta.id);

      final fallbackSurvey = OnboardingSurveyInput(
        heightCm: 175.0,
        weightKg: 70.0,
        ageYears: 20,
        sex: BiologicalSex.otherOrUnspecified,
        habitualBedtimeMinutesFromMidnight: null,
        habitualWakeMinutesFromMidnight: null,
        latencyAnswer: SurveySleepLatencyOption.unknown,
        sensitivityAnswer: SurveyNoiseSensitivityOption.unknown,
        cycleRhythmAnswer: SurveyCycleRhythmOption.unknown,
      );

      final userProfile = await unifier.initializeAndLoadProfile(
        fallbackSurvey: fallbackSurvey,
        enableAnalysisModeTonight: false,
        customProfileId: activeMeta.id,
      );

      emit(ProfileLoaded(
        profiles: remaining,
        activeProfile: activeMeta,
        activeUserProfile: userProfile,
      ));
    } catch (e) {
      emit(ProfileError('Failed to delete profile: $e'));
    }
  }
}

