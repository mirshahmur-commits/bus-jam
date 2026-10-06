import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ProgressStore {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesProgressStore implements ProgressStore {
  PreferencesProgressStore({this.key = defaultKey});
  final _preferences = SharedPreferencesAsync();
  static const defaultKey = 'bus_jam.progress.v1';
  final String key;
  @override
  Future<String?> read() => _preferences.getString(key);
  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}

class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
