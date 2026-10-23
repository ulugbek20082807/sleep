import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sleep_core_engine.dart';
import '../../core/sleep_engine_constants.dart';
import '../models/app_user_profile_meta.dart';

class ProfileRepository {
  static const String profilesRegistryKey = 'app_profiles_registry_v1';
  static const String activeProfileIdKey = 'app_active_profile_id_v1';

  final SharedPreferences _prefs;

  ProfileRepository(this._prefs);

  /// Retrieves list of all registered profile metas.
  Future<List<AppUserProfileMeta>> getProfiles() async {
    final String? raw = _prefs.getString(profilesRegistryKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => AppUserProfileMeta.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Retrieves currently active profile ID.
  Future<String?> getActiveProfileId() async {
    return _prefs.getString(activeProfileIdKey);
  }

  /// Sets the active profile ID.
  Future<void> setActiveProfileId(String? id) async {
    if (id == null) {
      await _prefs.remove(activeProfileIdKey);
    } else {
      await _prefs.setString(activeProfileIdKey, id);
    }
  }

  /// Saves a newly created profile meta and its initial UserProfileModel.
  Future<void> createProfile({
    required AppUserProfileMeta meta,
    required UserProfileModel userProfileModel,
  }) async {
    final List<AppUserProfileMeta> current = await getProfiles();
    final List<AppUserProfileMeta> updated = [...current, meta];
    await _prefs.setString(
      profilesRegistryKey,
      jsonEncode(updated.map((m) => m.toJson()).toList()),
    );

    // Save scientific UserProfileModel
    final String scientificKey =
        '${SleepEngineConstants.profileStorageKey}_${meta.id}';
    await _prefs.setString(
      scientificKey,
      jsonEncode(userProfileModel.toJson()),
    );

    // If no active profile set, set this one
    final String? activeId = await getActiveProfileId();
    if (activeId == null || current.isEmpty) {
      await setActiveProfileId(meta.id);
    }
  }

  /// Updates existing profile meta and optionally its UserProfileModel.
  Future<void> updateProfile({
    required AppUserProfileMeta meta,
    UserProfileModel? userProfileModel,
  }) async {
    final List<AppUserProfileMeta> current = await getProfiles();
    final List<AppUserProfileMeta> updated = current.map((p) {
      return p.id == meta.id ? meta : p;
    }).toList();

    await _prefs.setString(
      profilesRegistryKey,
      jsonEncode(updated.map((m) => m.toJson()).toList()),
    );

    if (userProfileModel != null) {
      final String scientificKey =
          '${SleepEngineConstants.profileStorageKey}_${meta.id}';
      await _prefs.setString(
        scientificKey,
        jsonEncode(userProfileModel.toJson()),
      );
    }
  }

  /// Loads the scientific UserProfileModel for a specific profile ID.
  Future<UserProfileModel?> getUserProfileModel(String profileId) async {
    final String scientificKey =
        '${SleepEngineConstants.profileStorageKey}_$profileId';
    final String? raw = _prefs.getString(scientificKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfileModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Persists an updated scientific UserProfileModel for a specific profile ID.
  Future<void> saveUserProfileModel(
      String profileId, UserProfileModel model) async {
    final String scientificKey =
        '${SleepEngineConstants.profileStorageKey}_$profileId';
    await _prefs.setString(scientificKey, jsonEncode(model.toJson()));
  }

  /// Deletes a profile, its scientific profile key, and its sleep history.
  Future<String?> deleteProfile(String profileId) async {
    final List<AppUserProfileMeta> current = await getProfiles();
    final List<AppUserProfileMeta> updated =
        current.where((p) => p.id != profileId).toList();

    await _prefs.setString(
      profilesRegistryKey,
      jsonEncode(updated.map((m) => m.toJson()).toList()),
    );

    // Delete scientific key
    final String scientificKey =
        '${SleepEngineConstants.profileStorageKey}_$profileId';
    await _prefs.remove(scientificKey);

    // Delete sleep history key
    final String historyKey = 'sleep_history_records_v1_$profileId';
    await _prefs.remove(historyKey);

    // Check active profile handling
    final String? currentActiveId = await getActiveProfileId();
    if (currentActiveId == profileId) {
      if (updated.isNotEmpty) {
        final String newActiveId = updated.first.id;
        await setActiveProfileId(newActiveId);
        return newActiveId;
      } else {
        await setActiveProfileId(null);
        return null;
      }
    }
    return currentActiveId;
  }
}

