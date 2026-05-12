import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool vibrationEnabled;
  final bool useAlarmSound;

  const AppSettings({
    this.vibrationEnabled = true,
    this.useAlarmSound = true,
  });

  AppSettings copyWith({
    bool? vibrationEnabled,
    bool? useAlarmSound,
  }) {
    return AppSettings(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      useAlarmSound: useAlarmSound ?? this.useAlarmSound,
    );
  }

  String get soundLabel => useAlarmSound ? 'Destacada' : 'Estandar';
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const _keyVibration = 'settings.vibrationEnabled';
  static const _keyUseAlarmSound = 'settings.useAlarmSound';

  late final Future<SharedPreferences> _prefsFuture =
      SharedPreferences.getInstance();

  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    state = state.copyWith(
      vibrationEnabled: prefs.getBool(_keyVibration) ?? state.vibrationEnabled,
      useAlarmSound: prefs.getBool(_keyUseAlarmSound) ?? state.useAlarmSound,
    );
  }

  Future<void> _persistBool(String key, bool value) async {
    final prefs = await _prefsFuture;
    await prefs.setBool(key, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    await _persistBool(_keyVibration, value);
  }

  Future<void> setUseAlarmSound(bool value) async {
    state = state.copyWith(useAlarmSound: value);
    await _persistBool(_keyUseAlarmSound, value);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
