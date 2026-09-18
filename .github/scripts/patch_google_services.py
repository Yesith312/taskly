"""
Aplica el plugin de Google Services, necesario para que google_sign_in
encuentre el cliente OAuth de Android automáticamente.

Flutter cambió el sistema de Gradle entre versiones: los proyectos más
nuevos declaran los plugins con id/version dentro de settings.gradle
(sintaxis moderna), en vez del classpath+apply plugin de antes
(sintaxis vieja). Este script detecta cuál tiene el proyecto y lo
aplica en el formato correcto.
"""
GOOGLE_SERVICES_VERSION = "4.4.2"

settings_path = "android/settings.gradle"
with open(settings_path) as f:
    settings = f.read()

app_path = "android/app/build.gradle"
with open(app_path) as f:
    app = f.read()

modern = 'id "com.android.application"' in settings or "id 'com.android.application'" in settings

if modern:
    print("Detectado formato moderno de Gradle (plugins en settings.gradle).")

    if "com.google.gms.google-services" not in settings:
        import re
        # Busca la línea COMPLETA del plugin de Android (con su versión y
        # "apply false" incluidos) y agrega la nuestra justo después,
        # sin cortar nada a la mitad.
        pattern = r'((?:id\s+["\']com\.android\.application["\'][^\n]*\n))'
        replacement = r'\1    id "com.google.gms.google-services" version "' + GOOGLE_SERVICES_VERSION + '" apply false\n'
        new_settings, count = re.subn(pattern, replacement, settings, count=1)
        if count == 0:
            raise SystemExit("No se encontró la línea de com.android.application en settings.gradle")
        settings = new_settings
        with open(settings_path, "w") as f:
            f.write(settings)

    if "com.google.gms.google-services" not in app:
        if "plugins {" in app:
            app = app.replace(
                "plugins {",
                'plugins {\n    id "com.google.gms.google-services"',
                1,
            )
        else:
            app += '\napply plugin: "com.google.gms.google-services"\n'
        with open(app_path, "w") as f:
            f.write(app)

else:
    print("Detectado formato clásico de Gradle (buildscript en build.gradle).")
    top_path = "android/build.gradle"
    with open(top_path) as f:
        top = f.read()

    if "com.google.gms:google-services" not in top:
        import re
        top = re.sub(
            r"(dependencies\s*\{)",
            r"\1\n        classpath 'com.google.gms:google-services:" + GOOGLE_SERVICES_VERSION + "'",
            top,
            count=1,
        )
        with open(top_path, "w") as f:
            f.write(top)

    if "com.google.gms.google-services" not in app:
        app += "\napply plugin: 'com.google.gms.google-services'\n"
        with open(app_path, "w") as f:
            f.write(app)

print("google-services plugin aplicado correctamente.")
