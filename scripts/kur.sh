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
python3 scripts/patch_android.py
flutter pub get
dart run flutter_launcher_icons || echo 'Uygulama simgesi olusturulamadi (istege bagli).'
echo 'Tamamlandi. flutter run ile baslatabilirsiniz.'
