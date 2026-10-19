import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState extends Equatable {
  final ThemeMode themeMode;
  final Locale locale;
  final String defaultCurrency;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('ar'),
    this.defaultCurrency = 'SAR',
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? defaultCurrency,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    );
  }

  @override
  List<Object?> get props => [themeMode, locale, defaultCurrency];
}

class AppSettingsCubit extends Cubit<AppSettingsState> {
  final SharedPreferences prefs;

  AppSettingsCubit(this.prefs) : super(const AppSettingsState()) {
    _loadSettings();
  }

  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyLanguage = 'app_language';
  static const String _keyCurrency = 'app_default_currency';

  void _loadSettings() {
    final themeStr = prefs.getString(_keyThemeMode);
    final themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final langStr = prefs.getString(_keyLanguage) ?? 'ar';
    final locale = Locale(langStr);

    final currency = prefs.getString(_keyCurrency) ?? 'SAR';

    emit(
      AppSettingsState(
        themeMode: themeMode,
        locale: locale,
        defaultCurrency: currency,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_keyThemeMode, str);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setLocale(Locale locale) async {
    await prefs.setString(_keyLanguage, locale.languageCode);
    emit(state.copyWith(locale: locale));
  }

  Future<void> setDefaultCurrency(String currency) async {
    await prefs.setString(_keyCurrency, currency);
    emit(state.copyWith(defaultCurrency: currency));
  }
}
