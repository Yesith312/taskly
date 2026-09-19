import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' show navigatorKey;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(t.language, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<Locale?>(
            title: Text(t.followSystemLanguage),
            value: null,
            groupValue: settings.locale,
            onChanged: (value) => settings.setLocale(value),
          ),
          RadioListTile<Locale?>(
            title: const Text('Español'),
            value: const Locale('es'),
            groupValue: settings.locale,
            onChanged: (value) => settings.setLocale(value),
          ),
          RadioListTile<Locale?>(
            title: const Text('English'),
            value: const Locale('en'),
            groupValue: settings.locale,
            onChanged: (value) => settings.setLocale(value),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(t.theme, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: Text(t.followSystemTheme),
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.setThemeMode(value!),
          ),
          RadioListTile<ThemeMode>(
            title: Text(t.lightTheme),
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.setThemeMode(value!),
          ),
          RadioListTile<ThemeMode>(
            title: Text(t.darkTheme),
            value: ThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.setThemeMode(value!),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(t.logout, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              await auth.signOut();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.loggedOut)),
              );
              await Future.delayed(const Duration(seconds: 3));
              // Sin esto, la app se queda "atascada" en Ajustes aunque
              // ya cerraste sesión: hay que volver a la pantalla raíz
              // para que se muestre el login de nuevo.
              navigatorKey.currentState?.popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
