"""
Patch android/app/build.gradle para que el APK release se firme con
nuestro keystore (guardado como GitHub Secret) en vez del keystore
debug aleatorio que Android genera solo. Sin esto, el SHA-1 cambiaría
en cada build de GitHub Actions y el login con Google se rompería.
"""
import re
import sys

path = "android/app/build.gradle"
with open(path) as f:
    content = f.read()

if "keystoreProperties" in content:
    print("build.gradle ya está parchado, no se toca de nuevo.")
    sys.exit(0)

# 1. Cargar key.properties (contraseñas/alias) antes del bloque android {
loader = '''def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

'''
content = content.replace("android {", loader + "android {", 1)

# 2. Insertar signingConfigs.release dentro del bloque android { ... }
signing_config = '''
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
'''
content = re.sub(r"(android\s*\{)", r"\1" + signing_config, content, count=1)

# 3. Apuntar el buildType release a nuestro signingConfig
content = content.replace(
    "signingConfig signingConfigs.debug",
    "signingConfig signingConfigs.release",
)

with open(path, "w") as f:
    f.write(content)

print("build.gradle parchado con la configuración de firma.")
