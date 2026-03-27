import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/firebase_support.dart';

class AppSettings {
  final bool vibrationEnabled;
  final bool isarEnabled;
  final bool firebaseEnabled;
  final bool useAlarmSound;

  const AppSettings({
    this.vibrationEnabled = true,
    this.isarEnabled = true,
    this.firebaseEnabled = true,
    this.useAlarmSound = true,
  });

  AppSettings copyWith({
    bool? vibrationEnabled,
    bool? isarEnabled,
    bool? firebaseEnabled,
    bool? useAlarmSound,
  }) {
    return AppSettings(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      isarEnabled: isarEnabled ?? this.isarEnabled,
      firebaseEnabled: firebaseEnabled ?? this.firebaseEnabled,
      useAlarmSound: useAlarmSound ?? this.useAlarmSound,
    );
  }

  String get soundLabel => useAlarmSound ? 'Alarma' : 'Sistema';
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const _keyVibration = 'settings.vibrationEnabled';
  static const _keyIsar = 'settings.isarEnabled';
  static const _keyFirebase = 'settings.firebaseEnabled';
  static const _keyUseAlarmSound = 'settings.useAlarmSound';

  late final Future<SharedPreferences> _prefsFuture =
      SharedPreferences.getInstance();

  AppSettingsNotifier()
      : super(
          AppSettings(
            firebaseEnabled: isFirebaseConfiguredForCurrentPlatform(),
          ),
        ) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    final firebaseAvailable = isFirebaseConfiguredForCurrentPlatform();
    state = state.copyWith(
      vibrationEnabled: prefs.getBool(_keyVibration) ?? state.vibrationEnabled,
      isarEnabled: prefs.getBool(_keyIsar) ?? state.isarEnabled,
      firebaseEnabled: firebaseAvailable
          ? (prefs.getBool(_keyFirebase) ?? state.firebaseEnabled)
          : false,
      useAlarmSound: prefs.getBool(_keyUseAlarmSound) ?? state.useAlarmSound,
    );

    if (!firebaseAvailable) {
      await _persistBool(_keyFirebase, false);
    }
  }

  Future<void> _persistBool(String key, bool value) async {
    final prefs = await _prefsFuture;
    await prefs.setBool(key, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    await _persistBool(_keyVibration, value);
  }

  Future<void> setIsarEnabled(bool value) async {
    state = state.copyWith(isarEnabled: value);
    await _persistBool(_keyIsar, value);
  }

  Future<void> setFirebaseEnabled(bool value) async {
    if (!isFirebaseConfiguredForCurrentPlatform()) {
      state = state.copyWith(firebaseEnabled: false);
      await _persistBool(_keyFirebase, false);
      return;
    }

    state = state.copyWith(firebaseEnabled: value);
    await _persistBool(_keyFirebase, value);
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
