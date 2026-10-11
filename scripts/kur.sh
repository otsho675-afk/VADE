#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "Flutter SDK PATH icinde yok." >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
flutter create --platforms=android,ios --org com.vadesi --project-name vadesi "$tmp"
[ -f .metadata ] || cp "$tmp/.metadata" .metadata
for folder in android ios; do
  if [ ! -d "$folder" ]; then cp -R "$tmp/$folder" "$folder"; fi
done
# Generated Gradle launchers are ignored by the native template; restore them
# when a checkout already contains the committed Android host directory.
for file in gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar; do
  if [ ! -f "android/$file" ]; then
    mkdir -p "$(dirname "android/$file")"
    cp "$tmp/android/$file" "android/$file"
  fi
done
chmod +x android/gradlew
python3 scripts/patch_android.py
python3 scripts/prepare_platforms.py
flutter pub get
dart run sqflite_common_ffi_web:setup
dart run flutter_launcher_icons
python3 - <<'PY'
from pathlib import Path
from xml.etree import ElementTree

path = Path('android/app/src/main/res/values/colors.xml')
root = ElementTree.parse(path).getroot()
assert root.tag == 'resources', f'{path}: kok resources olmali'
colors = {e.attrib.get('name'): (e.text or '').strip() for e in root.findall('color')}
for name in ('vadesi_splash_background', 'ic_launcher_background'):
    assert colors.get(name) == '#243F56', f'{path}: {name} rengi gecersiz'
print('VADESI Android renk kaynaklari dogrulandi.')
PY
echo 'Tamamlandi. flutter run ile baslatabilirsiniz.'
