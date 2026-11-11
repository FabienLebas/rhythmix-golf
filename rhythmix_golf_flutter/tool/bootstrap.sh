#!/usr/bin/env bash
# Prépare le projet Flutter : génère les dossiers android/ et ios/ (sans
# écraser lib/ ni pubspec.yaml), crée le plugin natif local, y copie le code
# Kotlin / Swift de native/, puis règle le nom, les permissions et le son en
# arrière-plan. À lancer une fois après un clone (le CI le fait tout seul).
set -euo pipefail
cd "$(dirname "$0")/.."
ORG=com.rhythmix

# 1. Plugin natif local (décodage vidéo)
if [ ! -f packages/rhythmix_native/pubspec.yaml ]; then
  flutter create --template=plugin --platforms=android,ios --org "$ORG" \
    --project-name rhythmix_native packages/rhythmix_native
  rm -rf packages/rhythmix_native/example packages/rhythmix_native/test \
         packages/rhythmix_native/android/src/test
fi
KT=$(find packages/rhythmix_native/android -name 'RhythmixNativePlugin.kt' | head -n 1)
SW=$(find packages/rhythmix_native/ios -name 'RhythmixNativePlugin.swift' | head -n 1)
if [ -z "$KT" ] || [ -z "$SW" ]; then
  echo "Fichiers du plugin introuvables (RhythmixNativePlugin.kt / .swift)" >&2
  exit 1
fi
cp native/android/RhythmixNativePlugin.kt "$KT"
cp native/ios/RhythmixNativePlugin.swift "$SW"
echo "Plugin natif : $KT et $SW"

# 2. Dossiers android/ et ios/ de l'application
if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --platforms=android,ios --org "$ORG" --project-name rhythmix_golf .
  rm -f test/widget_test.dart
fi

# 3. Nom affiché, permissions caméra / micro / photos, son en arrière-plan
python3 - <<'PY'
import plistlib, re, pathlib

plist = pathlib.Path('ios/Runner/Info.plist')
with plist.open('rb') as f:
    d = plistlib.load(f)
d['CFBundleDisplayName'] = 'Rhythmix Golf'
d['CFBundleName'] = 'Rhythmix Golf'
d['NSCameraUsageDescription'] = 'Rhythmix Golf filme ton swing pour mesurer ton tempo.'
d['NSMicrophoneUsageDescription'] = "Le son de la vidéo sert à repérer l'impact de la balle."
d['NSPhotoLibraryUsageDescription'] = "Rhythmix Golf ouvre les vidéos de ton swing pour les analyser."
modes = d.get('UIBackgroundModes', [])
if 'audio' not in modes:
    modes.append('audio')
d['UIBackgroundModes'] = modes
with plist.open('wb') as f:
    plistlib.dump(d, f)

man = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = man.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="Rhythmix Golf"', s, count=1)
man.write_text(s)
print('Info.plist et AndroidManifest.xml mis à jour')
PY

flutter pub get
echo "Projet prêt. Android : flutter build apk --release · iOS (Mac) : flutter run --release"
