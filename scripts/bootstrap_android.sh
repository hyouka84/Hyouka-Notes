#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required to generate the Android project." >&2
  exit 1
fi

flutter create --no-pub --platforms=android --org com.hyouka --project-name notes "$TMP_DIR/seed"
rm -rf "$ROOT_DIR/android"
cp -a "$TMP_DIR/seed/android" "$ROOT_DIR/android"

RES="$ROOT_DIR/android/app/src/main/res"
mkdir -p "$RES/mipmap-anydpi" "$RES/mipmap-anydpi-v26" "$RES/mipmap-anydpi-v33" "$RES/drawable" "$RES/values"

cp "$ROOT_DIR/tool/android/ic_launcher_fallback.xml" "$RES/mipmap-anydpi/ic_launcher.xml"
cp "$ROOT_DIR/tool/android/ic_launcher.xml" "$RES/mipmap-anydpi-v26/ic_launcher.xml"
cp "$ROOT_DIR/tool/android/ic_launcher_monochrome.xml" "$RES/mipmap-anydpi-v33/ic_launcher.xml"
cp "$ROOT_DIR/tool/android/ic_notes_foreground.xml" "$RES/drawable/ic_notes_foreground.xml"
cp "$ROOT_DIR/tool/android/ic_launcher_background.xml" "$RES/values/ic_launcher_background.xml"

MANIFEST="$ROOT_DIR/android/app/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys

manifest = Path(sys.argv[1])
text = manifest.read_text(encoding="utf-8")
text = text.replace('android:label="notes"', 'android:label="Hyouka Notes"')
manifest.write_text(text, encoding="utf-8")
if 'android:label="Hyouka Notes"' not in text:
    raise SystemExit("Could not set the Android app label.")
PY

echo "Generated Android project with application ID com.hyouka.notes and pure-black/white launcher icon."
