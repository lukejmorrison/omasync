#!/usr/bin/env bash
# Create a fresh Flutter iOS/Android project and overlay the OmaSync shell.
# Usage:  ./bootstrap.sh
# Then:   cd ../omasync-phone && flutter run
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PARENT="$(cd "$HERE/.." && pwd)"
OUT="${OMASYNC_PHONE_DIR:-$PARENT/omasync-phone}"

if ! command -v flutter >/dev/null; then
  echo "flutter not on PATH" >&2
  exit 1
fi

if [[ "$(basename "$PWD")" == "fishhook-app" || "$PWD" == *"/FishHook/"* ]]; then
  echo "this is FishHook, not OmaSync. Run from ~/dev/omasync/mobile" >&2
  exit 1
fi

echo "→ fresh Flutter project at $OUT"
rm -rf "$OUT"
flutter create --org com.wizwam --project-name omasync --platforms=ios,android "$OUT"

echo "→ overlay OmaSync shell (lib + pubspec)"
rm -rf "$OUT/lib"
cp -a "$HERE/lib" "$OUT/lib"
cp "$HERE/pubspec.yaml" "$OUT/pubspec.yaml"
if [[ -f "$HERE/analysis_options.yaml" ]]; then
  cp "$HERE/analysis_options.yaml" "$OUT/analysis_options.yaml"
fi

# Force Android v2 embedding (Flutter 3.16+ deleted v1).
MANIFEST="$OUT/android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]]; then
  python3 - "$MANIFEST" <<'PY'
import pathlib, sys, re
p = pathlib.Path(sys.argv[1])
t = p.read_text()
t = t.replace("io.flutter.app.FlutterApplication", "${applicationName}")
if "flutterEmbedding" not in t:
    t = t.replace(
        "</application>",
        '        <meta-data android:name="flutterEmbedding" android:value="2" />\n    </application>',
    )
p.write_text(t)
PY
fi

MAIN_KT=$(find "$OUT/android" -name 'MainActivity.kt' | head -n1)
if [[ -n "$MAIN_KT" ]]; then
  cat >"$MAIN_KT" <<'KT'
package com.wizwam.omasync

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
KT
fi

cd "$OUT"
flutter pub get

echo
echo "done.  $OUT"
echo "  USB Pixel:     flutter run -d 57250DLAQ0020D"
echo "  list devices:  flutter devices"
echo
echo "Do not run this inside FishHook or omamusic."
