// ⚠️ ESTE ARCHIVO ES UN PLACEHOLDER. NO FUNCIONARÁ TAL CUAL.
//
// Este archivo normalmente se genera automáticamente con el comando:
//   flutterfire configure
// después de crear tu proyecto en https://console.firebase.google.com
//
// Ese comando lee tu proyecto de Firebase y reemplaza este archivo
// completo con tus claves reales (apiKey, appId, projectId, etc.),
// una sección por plataforma (Android, iOS, Web).
//
// Instrucciones completas en el README.md, sección "Configurar Firebase".

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Corre `flutterfire configure` para generar las opciones reales.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma.',
        );
    }
  }

  // TODO: reemplazar estos 4 valores con los de TU proyecto de Firebase
  // (Project settings > General > Your apps > Android app).
  static const android = FirebaseOptions(
    apiKey: 'REEMPLAZA_CON_TU_API_KEY',
    appId: 'REEMPLAZA_CON_TU_APP_ID',
    messagingSenderId: 'REEMPLAZA_CON_TU_SENDER_ID',
    projectId: 'REEMPLAZA_CON_TU_PROJECT_ID',
    storageBucket: 'REEMPLAZA_CON_TU_PROJECT_ID.appspot.com',
  );

  // TODO: reemplazar con los datos de tu app de iOS en Firebase.
  static const ios = FirebaseOptions(
    apiKey: 'REEMPLAZA_CON_TU_API_KEY',
    appId: 'REEMPLAZA_CON_TU_APP_ID',
    messagingSenderId: 'REEMPLAZA_CON_TU_SENDER_ID',
    projectId: 'REEMPLAZA_CON_TU_PROJECT_ID',
    storageBucket: 'REEMPLAZA_CON_TU_PROJECT_ID.appspot.com',
    iosBundleId: 'com.taskly.app',
  );
}
