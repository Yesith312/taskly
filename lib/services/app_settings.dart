import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda y aplica las preferencias de idioma y tema del usuario.
/// 'system' significa "seguir el idioma/tema del celular" (el
/// comportamiento que tenía la app antes); cualquier otro valor fuerza
/// esa opción sin importar la configuración del sistema operativo.
class AppSettings extends ChangeNotifier {
  static const _localeKey = 'taskly_locale';
  static const _themeKey = 'taskly_theme';

  Locale? _locale; // null = seguir el idioma del sistema
  ThemeMode _themeMode = ThemeMode.system;

  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final localeCode = prefs.getString(_localeKey);
    _locale = (localeCode == null || localeCode == 'system')
        ? null
        : Locale(localeCode);

    final themeString = prefs.getString(_themeKey);
    _themeMode = switch (themeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale?.languageCode ?? 'system');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeKey, value);
  }
}
