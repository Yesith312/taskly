#!/usr/bin/env bash
set -euo pipefail

echo "== 1. Generando carpeta android/ =="
flutter create --platforms=android --org com.taskly --project-name app .

echo "== 1.1 Configurando nombre de la aplicación: Taskly =="

sed -i 's/android:label="app"/android:label="Taskly"/' \
  android/app/src/main/AndroidManifest.xml

echo "✓ Nombre configurado como Taskly"

echo "== 1.2 Configurando minSdk = 23 =="

python3 - <<'PY'
from pathlib import Path

path = Path("android/app/build.gradle")
text = path.read_text()
original = text

text = text.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")
text = text.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 23")

if text == original:
    print("⚠️ No se encontró la configuración de minSdk de Flutter.")
else:
    path.write_text(text)
    print("✓ minSdk configurado en 23")
PY

echo "== 2. Copiando archivos nativos del widget =="

mkdir -p android/app/src/main/kotlin/com/taskly/app
mkdir -p android/app/src/main/res/layout
mkdir -p android/app/src/main/res/xml

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

echo "== 4. Configurando la firma del APK =="

python3 .github/scripts/patch_signing.py

echo "== 4.1 Aplicando Google Services =="

python3 .github/scripts/patch_google_services.py

echo "== 4.2 Actualizando Kotlin =="

sed -i -E 's/(id "org\.jetbrains\.kotlin\.android" version )"[^"]+"/\1"1.9.22"/' android/settings.gradle
sed -i -E "s/(id 'org\.jetbrains\.kotlin\.android' version )'[^']+'/\1'1.9.22'/" android/settings.gradle

echo "== 5. Configurando Firebase =="

sed -i \
  -e "s/REEMPLAZA_CON_TU_API_KEY/${FIREBASE_API_KEY}/g" \
  -e "s/REEMPLAZA_CON_TU_APP_ID/${FIREBASE_APP_ID}/g" \
  -e "s/REEMPLAZA_CON_TU_SENDER_ID/${FIREBASE_SENDER_ID}/g" \
  -e "s/REEMPLAZA_CON_TU_PROJECT_ID/${FIREBASE_PROJECT_ID}/g" \
  lib/firebase_options.dart

echo "== Verificación minSdk =="

grep -n "minSdk" android/app/build.gradle || true

echo "== Listo =="
