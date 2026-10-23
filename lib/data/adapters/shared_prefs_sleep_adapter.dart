import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sleep_core_engine.dart';

/// Implements [SleepProfileStorageAdapter] using Flutter's [SharedPreferences].
class SharedPrefsSleepAdapter implements SleepProfileStorageAdapter {
  final SharedPreferences _prefs;

  SharedPrefsSleepAdapter(this._prefs);

  @override
  Future<String?> readString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<bool> writeString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  /// Removes a stored key from SharedPreferences.
  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }
}
