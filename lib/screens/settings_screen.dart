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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Idioma / Language',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<Locale?>(
            title: const Text('Seguir el idioma del celular'),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Tema', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Seguir el tema del celular'),
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.setThemeMode(value!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Claro'),
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.setThemeMode(value!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Oscuro'),
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
