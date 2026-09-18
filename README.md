# Taskly — App de tareas de colegio y trabajo

Este zip trae todo el **código Dart** de la app (pantallas, lógica de
notificaciones, autenticación, tareas, multilenguaje) y un workflow de
**GitHub Actions que compila el APK por ti en la nube** — no necesitas
que `flutter` funcione en tu celular/Termux para nada. Termux solo se
usa aquí para editar y subir archivos con `git`.

> ¿Por qué así? Flutter tiene un problema conocido de compatibilidad
> compilando directo dentro de Termux en Android reciente (error de
> alineación TLS del binario de Dart). GitHub Actions corre en un
> servidor Linux normal, así que ese problema no existe ahí.

## 1. Subir este proyecto a GitHub

En Termux (esto sí funciona sin problema, es solo `git`):

```bash
pkg install git
cd taskly   # la carpeta que viene dentro de este zip
git init
git add .
git commit -m "Proyecto inicial de Taskly"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/taskly.git
git push -u origin main
```

(Crea antes el repo vacío en github.com, sin README ni licencia, para
que el `git push` no choque con nada.)

## 2. Configurar Firebase (todo desde el navegador, sin CLI)

1. Ve a https://console.firebase.google.com y crea un proyecto nuevo.
2. Activa **Authentication** → habilita el proveedor **Google**.
3. Activa **Firestore Database** (modo producción).
4. En Firestore, pega el contenido de `firestore.rules` en la pestaña
   "Reglas" y publica.
5. Ve a **Configuración del proyecto** (el engranaje) → pestaña
   **General** → sección "Tus apps" → agrega una app **Android** con
   el paquete `com.taskly.app`. Firebase te muestra un panel con:
   `apiKey`, `appId`, `messagingSenderId`, `projectId` — estos 4
   valores son los que necesitas para el paso 3.

## 3. Guardar las claves como GitHub Secrets

En tu repo de GitHub: **Settings → Secrets and variables → Actions →
New repository secret**. Crea estos 4 secrets exactos (el nombre debe
ser idéntico, en mayúsculas):

| Nombre del secret        | De dónde sale                                |
|---------------------------|-----------------------------------------------|
| `FIREBASE_API_KEY`        | Firebase → apiKey                             |
| `FIREBASE_APP_ID`         | Firebase → appId                              |
| `FIREBASE_SENDER_ID`      | Firebase → messagingSenderId                  |
| `FIREBASE_PROJECT_ID`     | Firebase → projectId                          |
| `KEYSTORE_BASE64`         | Ver sección "Firmar el APK" abajo             |
| `KEYSTORE_PASSWORD`       | La contraseña que pusiste al crear el keystore|
| `KEY_ALIAS`               | `taskly` (o el alias que hayas usado)         |
| `KEY_PASSWORD`            | La contraseña de la key (puede ser la misma)  |
| `GOOGLE_SERVICES_JSON_BASE64` | Ver sección "google-services.json" abajo  |

No hace falta tocar ningún archivo del proyecto a mano: el workflow
(`.github/workflows/build.yml`) toma estos secrets y arma todo solo
(`.github/scripts/prepare_android.sh` es el que hace ese trabajo).

## 3.1 Firmar el APK (necesario para que Google Sign-In funcione)

Google necesita la huella SHA-1 de tu app para dejar iniciar sesión con
Google. Si el APK se firmara distinto cada vez, ese SHA-1 cambiaría y
el login se rompería — por eso usamos siempre el mismo "keystore".

**Generarlo (una sola vez, en Termux):**
```bash
keytool -genkey -v -keystore taskly-release.keystore -alias taskly \
  -keyalg RSA -keysize 2048 -validity 10000
```
Guarda bien la(s) contraseña(s) que pongas — las vas a necesitar para
los secrets `KEYSTORE_PASSWORD` y `KEY_PASSWORD`.

**Sacar el SHA-1 y registrarlo en Firebase:**
```bash
keytool -list -v -keystore taskly-release.keystore -alias taskly
```
Copia la línea que empieza con `SHA1:`. Ve a Firebase → Project
settings → Your apps → tu app Android → **Add fingerprint**, y pégalo
ahí.

**Subir el keystore como secret (en base64, no como archivo):**
```bash
base64 -w 0 taskly-release.keystore > keystore_base64.txt
cat keystore_base64.txt
```
Copia TODO ese texto larguísimo y pégalo como el secret
`KEYSTORE_BASE64` en GitHub. Guarda también `taskly-release.keystore`
en un lugar seguro de tu celular — si lo pierdes, no vas a poder volver
a firmar la app igual, y tocaría empezar de cero con un SHA-1 nuevo.

## 3.2 google-services.json (necesario para que funcione Google Sign-In)

1. En Firebase Console → **Project settings** → pestaña **General** →
   "Your apps" → tu app Android → busca el link de descarga
   **"google-services.json"** y descárgalo al celular.
2. Muévelo (o cópialo) a la misma carpeta donde tienes el proyecto en
   Termux, y conviértelo a base64:
   ```bash
   base64 -w 0 google-services.json > google_services_base64.txt
   cat google_services_base64.txt
   ```
3. Copia ese texto y pégalo como el secret `GOOGLE_SERVICES_JSON_BASE64`
   en GitHub (mismo lugar que los demás secrets).

## 4. Compilar

Con los secrets ya guardados, cualquier `git push` a la rama `main`
dispara la compilación sola. También puedes forzarla a mano: en GitHub,
pestaña **Actions** → selecciona el workflow "Build Taskly APK" →
**Run workflow**.

Cuando termine (tarda unos 5-10 minutos), entra al run que corrió,
baja hasta **Artifacts**, y descarga `taskly-apk` — ahí adentro está
`app-release.apk`, listo para instalar en cualquier Android.

## 5. El widget y el diseño ya quedan incluidos

El script `prepare_android.sh` ya copia los archivos de
`android_widget_files/` y los registra automáticamente en el
`AndroidManifest.xml` que Flutter genera — no tienes que copiar nada
de eso a mano.

## 6. iPhone

Para compilar la versión de iOS necesitas obligatoriamente una Mac con
Xcode instalado (no hay forma de evitar esto, es una restricción de
Apple, no de Flutter). El mismo código de `lib/` sirve tal cual —
solo hay que abrir `ios/Runner.xcworkspace` en Xcode, repetir el paso
de Facebook para iOS, y compilar desde ahí.

## Qué falta para producción real

- [ ] Selector de idioma manual dentro de Ajustes (ahora mismo sigue el
      idioma del sistema operativo)
- [ ] Meter los assets del logo/íconos definitivos en `assets/images/`
- [ ] Widget nativo de iOS (WidgetKit, requiere Xcode)
- [ ] Cloud Function opcional en Firebase para reforzar el recordatorio
      semanal también cuando el celular está apagado varios días
      (ahora mismo el recordatorio semanal es 100% local, funciona
      bien pero depende de que el celular se prenda esa semana)
- [ ] Pruebas en dispositivos reales antes de publicar
- [ ] Si el repo de GitHub es público, cualquiera puede ver el código,
      pero los Secrets NUNCA aparecen en los logs ni en el código —
      aun así, si prefieres más privacidad, puedes poner el repo como
      privado sin que esto afecte el workflow
