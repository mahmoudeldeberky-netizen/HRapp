import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app settings: theme mode (light/dark/system) and locale (en/ar).
/// Locale drives text direction automatically — 'ar' renders full RTL.

const _kThemeKey = 'settings.themeMode';
const _kLocaleKey = 'settings.locale';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override in main() after SharedPreferences.getInstance(), '
    'or leave unoverridden to use in-memory defaults in tests.',
  ),
);

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = _prefs?.getString(_kThemeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs?.setString(_kThemeKey, mode.name);
  }

  Future<void> toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = _prefs?.getString(_kLocaleKey);
    if (stored != null) return Locale(stored);
    final device = PlatformDispatcher.instance.locale;
    return device.languageCode == 'ar' ? const Locale('ar') : const Locale('en');
  }

  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  Future<void> set(Locale locale) async {
    assert(locale.languageCode == 'en' || locale.languageCode == 'ar');
    state = locale;
    await _prefs?.setString(_kLocaleKey, locale.languageCode);
  }

  Future<void> toggle() =>
      set(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
}
