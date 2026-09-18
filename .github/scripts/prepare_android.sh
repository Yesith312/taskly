#!/usr/bin/env bash

set -euo pipefail

echo "=========================================="
echo " TASKLY - PREPARACIÓN ANDROID"
echo "=========================================="

# ============================================================
# 1. Generar carpeta android/
# ============================================================

echo ""
echo "== 1. Generando carpeta android/ =="

flutter create \
  --platforms=android \
  --org com.taskly \
  --project-name app \
  .

echo "✓ Carpeta android/ generada"


# ============================================================
# 2. Configurar nombre, minSdk e INTERNET
# ============================================================

echo ""
echo "== 2. Configurando AndroidManifest.xml =="

python3 - <<'PY'
from pathlib import Path

path = Path("android/app/src/main/AndroidManifest.xml")
content = path.read_text()

# ------------------------------------------------------------
# Nombre visible de la aplicación
# ------------------------------------------------------------

content = content.replace(
    'android:label="app"',
    'android:label="Taskly"'
)

# Por si Flutter hubiera generado otro label
content = content.replace(
    'android:label="@string/app_name"',
    'android:label="Taskly"'
)

# ------------------------------------------------------------
# Permiso INTERNET
# Necesario para Firebase / Google Sign-In
# ------------------------------------------------------------

permission = '<uses-permission android:name="android.permission.INTERNET" />'

if permission not in content:
    content = content.replace(
        '<application',
        permission + '\n\n    <application',
        1
    )

path.write_text(content)

print("✓ Nombre: Taskly")
print("✓ INTERNET configurado")
PY


# ============================================================
# 3. Configurar minSdk = 23
# ============================================================

echo ""
echo "== 3. Configurando minSdk = 23 =="

python3 - <<'PY'
from pathlib import Path

path = Path("android/app/build.gradle")
content = path.read_text()

original = content

# Flutter 3.24 normalmente genera esto:
content = content.replace(
    "minSdk = flutter.minSdkVersion",
    "minSdk = 23"
)

# Compatibilidad con formato antiguo:
content = content.replace(
    "minSdkVersion flutter.minSdkVersion",
    "minSdkVersion 23"
)

if content == original:
    print("⚠️ No se encontró minSdk de Flutter.")
    print("Revisa android/app/build.gradle")
else:
    path.write_text(content)
    print("✓ minSdk = 23")
PY


# ============================================================
# 4. Copiar archivos del widget
# ============================================================

echo ""
echo "== 4. Configurando widget Android =="

mkdir -p android/app/src/main/kotlin/com/taskly/app
mkdir -p android/app/src/main/res/layout
mkdir -p android/app/src/main/res/xml

cp android_widget_files/kotlin/TasklyWidgetProvider.kt \
   android/app/src/main/kotlin/com/taskly/app/TasklyWidgetProvider.kt

cp android_widget_files/res/layout/taskly_widget.xml \
   android/app/src/main/res/layout/taskly_widget.xml

cp android_widget_files/res/xml/taskly_widget_info.xml \
   android/app/src/main/res/xml/taskly_widget_info.xml

echo "✓ Archivos del widget copiados"


# ============================================================
# 5. Registrar widget en AndroidManifest
# ============================================================

echo ""
echo "== 5. Registrando widget en AndroidManifest.xml =="

MANIFEST="android/app/src/main/AndroidManifest.xml"

if ! grep -q "TasklyWidgetProvider" "$MANIFEST"; then

    python3 - "$MANIFEST" <<'PY'
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as f:
    content = f.read()

receiver = '''
        <receiver
            android:name=".TasklyWidgetProvider"
            android:exported="false">

            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>

            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/taskly_widget_info" />

        </receiver>
'''

if "</application>" not in content:
    raise SystemExit(
        "❌ No se encontró </application> en AndroidManifest.xml"
    )

content = content.replace(
    "</application>",
    receiver + "\n    </application>",
    1
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("✓ Widget registrado")
PY

else
    echo "✓ Widget ya estaba registrado"
fi


# ============================================================
# 6. Configurar firma Release
# ============================================================

echo ""
echo "== 6. Configurando firma Release =="

python3 .github/scripts/patch_signing.py

echo "✓ Firma configurada"


# ============================================================
# 7. Configurar Google Services
# ============================================================

echo ""
echo "== 7. Configurando Google Services =="

python3 .github/scripts/patch_google_services.py

echo "✓ Google Services configurado"


# ============================================================
# 8. Actualizar Kotlin
# ============================================================

echo ""
echo "== 8. Actualizando Kotlin a 1.9.22 =="

sed -i -E \
  's/(id "org\.jetbrains\.kotlin\.android" version )"[^"]+"/\1"1.9.22"/' \
  android/settings.gradle

sed -i -E \
  "s/(id 'org\.jetbrains\.kotlin\.android' version )'[^']+'/\\1'1.9.22'/" \
  android/settings.gradle

echo "✓ Kotlin configurado"


# ============================================================
# 9. Configurar Firebase options
# ============================================================

echo ""
echo "== 9. Configurando Firebase =="

if [ ! -f "lib/firebase_options.dart" ]; then
    echo "❌ No existe lib/firebase_options.dart"
    exit 1
fi

sed -i \
  -e "s/REEMPLAZA_CON_TU_API_KEY/${FIREBASE_API_KEY}/g" \
  -e "s/REEMPLAZA_CON_TU_APP_ID/${FIREBASE_APP_ID}/g" \
  -e "s/REEMPLAZA_CON_TU_SENDER_ID/${FIREBASE_SENDER_ID}/g" \
  -e "s/REEMPLAZA_CON_TU_PROJECT_ID/${FIREBASE_PROJECT_ID}/g" \
  lib/firebase_options.dart

echo "✓ Firebase configurado"


# ============================================================
# 10. Mostrar configuración final
# ============================================================

echo ""
echo "=========================================="
echo " CONFIGURACIÓN FINAL"
echo "=========================================="

echo ""
echo "Application ID:"
grep -n "applicationId" android/app/build.gradle || true

echo ""
echo "minSdk:"
grep -n "minSdk" android/app/build.gradle || true

echo ""
echo "Nombre:"
grep -n 'android:label' android/app/src/main/AndroidManifest.xml || true

echo ""
echo "INTERNET:"
grep -n "android.permission.INTERNET" \
  android/app/src/main/AndroidManifest.xml || true

echo ""
echo "Widget:"
grep -n "TasklyWidgetProvider" \
  android/app/src/main/AndroidManifest.xml || true

echo ""
echo "=========================================="
echo " ✓ ANDROID CONFIGURADO CORRECTAMENTE"
echo "=========================================="
