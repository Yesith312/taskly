"""
Aplica el plugin de Google Services a los build.gradle (top-level y
de app), necesario para que el paquete google_sign_in encuentre
automáticamente el cliente OAuth correcto en Android.
"""
import re

# 1. android/build.gradle (top-level): agregar el classpath del plugin
top_path = "android/build.gradle"
with open(top_path) as f:
    top = f.read()

if "com.google.gms:google-services" not in top:
    top = re.sub(
        r"(dependencies\s*\{)",
        r"\1\n        classpath 'com.google.gms:google-services:4.4.2'",
        top,
        count=1,
    )
    with open(top_path, "w") as f:
        f.write(top)

# 2. android/app/build.gradle: aplicar el plugin al final del archivo
app_path = "android/app/build.gradle"
with open(app_path) as f:
    app = f.read()

if "com.google.gms.google-services" not in app:
    app += "\napply plugin: 'com.google.gms.google-services'\n"
    with open(app_path, "w") as f:
        f.write(app)

print("google-services plugin aplicado en ambos build.gradle.")
