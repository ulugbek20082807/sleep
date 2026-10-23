import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_session_record.dart';

class SleepHistoryRepository {
  final SharedPreferences _prefs;

  SleepHistoryRepository(this._prefs);

  String _getKey(String profileId) => 'sleep_history_records_v1_$profileId';

  /// Loads all sleep records for a specific profile, ordered newest first.
  Future<List<SleepSessionRecord>> getHistory(String profileId) async {
    final String? raw = _prefs.getString(_getKey(profileId));
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final records = list
          .map((item) =>
              SleepSessionRecord.fromJson(item as Map<String, dynamic>))
          .toList();
      // Sort newest first based on sleepStartTime
      records.sort((a, b) => b.sleepStartTime.compareTo(a.sleepStartTime));
      return records;
    } catch (_) {
      return [];
    }
  }

  /// Appends or inserts a new sleep session record at the front.
  Future<void> addRecord(SleepSessionRecord record) async {
    final List<SleepSessionRecord> current = await getHistory(record.profileId);
    final List<SleepSessionRecord> updated = [
      record,
      ...current.where((r) => r.sessionId != record.sessionId),
    ];
    await _prefs.setString(
      _getKey(record.profileId),
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    );
  }

  /// Deletes a specific session record from the profile's history.
  Future<void> deleteRecord(String profileId, String sessionId) async {
    final List<SleepSessionRecord> current = await getHistory(profileId);
    final List<SleepSessionRecord> updated =
        current.where((r) => r.sessionId != sessionId).toList();
    await _prefs.setString(
      _getKey(profileId),
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    );
  }

  /// Clears all history for a profile.
  Future<void> clearHistory(String profileId) async {
    await _prefs.remove(_getKey(profileId));
  }
}

