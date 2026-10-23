import 'package:equatable/equatable.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileZeroProfiles extends ProfileState {
  const ProfileZeroProfiles();
}

class ProfileLoaded extends ProfileState {
  final List<AppUserProfileMeta> profiles;
  final AppUserProfileMeta activeProfile;
  final UserProfileModel activeUserProfile;

  const ProfileLoaded({
    required this.profiles,
    required this.activeProfile,
    required this.activeUserProfile,
  });

  @override
  List<Object?> get props => [profiles, activeProfile, activeUserProfile];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

