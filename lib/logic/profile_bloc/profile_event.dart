import 'package:equatable/equatable.dart';
import '../../core/sleep_core_engine.dart';
import '../../data/models/app_user_profile_meta.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfilesEvent extends ProfileEvent {
  const LoadProfilesEvent();
}

class CreateProfileEvent extends ProfileEvent {
  final String displayName;
  final String? avatarPath;
  final OnboardingSurveyInput survey;

  const CreateProfileEvent({
    required this.displayName,
    this.avatarPath,
    required this.survey,
  });

  @override
  List<Object?> get props => [displayName, avatarPath, survey];
}

class SwitchProfileEvent extends ProfileEvent {
  final String targetProfileId;

  const SwitchProfileEvent({required this.targetProfileId});

  @override
  List<Object?> get props => [targetProfileId];
}

class EditProfileEvent extends ProfileEvent {
  final AppUserProfileMeta meta;
  final UserProfileModel? updatedUserProfile;

  const EditProfileEvent({
    required this.meta,
    this.updatedUserProfile,
  });

  @override
  List<Object?> get props => [meta, updatedUserProfile];
}

class DeleteProfileEvent extends ProfileEvent {
  final String profileId;

  const DeleteProfileEvent({required this.profileId});

  @override
  List<Object?> get props => [profileId];
}

