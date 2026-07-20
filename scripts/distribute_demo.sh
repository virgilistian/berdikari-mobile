#!/usr/bin/env bash
# Builds a signed release APK and pushes it to Firebase App Distribution.
# Run from Git Bash / WSL / macOS / Linux: ./scripts/distribute_demo.sh ["release notes"]
set -euo pipefail

cd "$(dirname "$0")/.."

RELEASE_NOTES="${1:-Demo build for Berdikari pilot testers.}"
API_BASE_URL="${API_BASE_URL:-https://berdikari-api.fly.dev/api/v1}"

if [ ! -f android/key.properties ]; then
  echo "Missing android/key.properties." >&2
  echo "Copy android/key.properties.example to android/key.properties and fill in your keystore details first." >&2
  exit 1
fi

if [ -z "${FIREBASE_APP_ID:-}" ]; then
  echo "Set FIREBASE_APP_ID first, e.g.:" >&2
  echo "  export FIREBASE_APP_ID=1:xxxxxxxxxxxx:android:xxxxxxxxxxxxxxxx" >&2
  echo "(Firebase console > Project settings > Your apps > Android app)" >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "Firebase CLI not found." >&2
  echo "Install it once: npm install -g firebase-tools" >&2
  echo "Then log in once: firebase login" >&2
  exit 1
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter gen-l10n"
flutter gen-l10n

echo "==> Building signed release APK (API_BASE_URL=$API_BASE_URL)"
flutter build apk --release --dart-define=API_BASE_URL="$API_BASE_URL"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo "==> Uploading to Firebase App Distribution (group: demo-testers)"
firebase appdistribution:distribute "$APK_PATH" \
  --app "$FIREBASE_APP_ID" \
  --groups "demo-testers" \
  --release-notes "$RELEASE_NOTES"

echo "Done. Testers in the demo-testers group get a notification with an install link."
