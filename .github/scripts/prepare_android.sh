#!/usr/bin/env bash
# Este script lo corre GitHub Actions (no tienes que ejecutarlo tú a mano).
# Arma todo lo que en Termux hubieras tenido que copiar/pegar manualmente:
#  - genera android/ con `flutter create`
#  - copia los archivos del widget nativo
#  - registra el widget en AndroidManifest.xml
#  - rellena lib/firebase_options.dart con las claves de Firebase (desde Secrets)
set -euo pipefail

echo "== 1. Generando carpeta android/ (si falta) =="
flutter create --platforms=android --org com.taskly .

echo "== 2. Copiando archivos nativos del widget =="
mkdir -p android/app/src/main/kotlin/com/taskly/app
cp android_widget_files/kotlin/TasklyWidgetProvider.kt \
   android/app/src/main/kotlin/com/taskly/app/TasklyWidgetProvider.kt
cp android_widget_files/res/layout/taskly_widget.xml \
   android/app/src/main/res/layout/taskly_widget.xml
cp android_widget_files/res/xml/taskly_widget_info.xml \
   android/app/src/main/res/xml/taskly_widget_info.xml

echo "== 3. Registrando el widget en AndroidManifest.xml =="
MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q "TasklyWidgetProvider" "$MANIFEST"; then
  python3 - "$MANIFEST" <<'PY'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

receiver = '''
        <receiver android:name=".TasklyWidgetProvider" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/taskly_widget_info" />
        </receiver>
'''

content = content.replace("</application>", receiver + "    </application>")
with open(path, "w") as f:
    f.write(content)
PY
fi

echo "== 4. Configurando la firma del APK (para que el SHA-1 no cambie nunca) =="
python3 .github/scripts/patch_signing.py

echo "== 5. Rellenando lib/firebase_options.dart con las claves de Firebase =="
sed -i \
  -e "s/REEMPLAZA_CON_TU_API_KEY/${FIREBASE_API_KEY}/g" \
  -e "s/REEMPLAZA_CON_TU_APP_ID/${FIREBASE_APP_ID}/g" \
  -e "s/REEMPLAZA_CON_TU_SENDER_ID/${FIREBASE_SENDER_ID}/g" \
  -e "s/REEMPLAZA_CON_TU_PROJECT_ID/${FIREBASE_PROJECT_ID}/g" \
  lib/firebase_options.dart

echo "== Listo, carpeta android/ configurada =="

