# Hyouka Notes

An offline-first Flutter notes app with a pure-black AMOLED interface and a white centered note glyph for the launcher icon.

## Features

- Create and edit notes saved locally on the device.
- Search note titles, text, and categories.
- Pin important notes and keep them at the top.
- Categories: Personal, Work, Ideas, and Other.
- Delete notes only after confirmation.
- No sign-in, cloud account, analytics, or remote service.
- Pure-black backgrounds with white text and icons.

## Android build

The Android project scaffold is generated reproducibly by the bootstrap script.

```sh
flutter pub get
bash scripts/bootstrap_android.sh
flutter analyze
flutter test --reporter expanded
flutter build apk --release --target-platform android-arm64
```

The GitHub Actions workflow runs format checks, analysis, widget tests, and an ARM64-only release APK build. The resulting APK is uploaded as the `hyouka-notes-arm64-apk` artifact.

## Local storage

Notes are stored on the device through SharedPreferences. They are not synchronized or backed up to a server. Removing app data or uninstalling the app can remove the locally stored notes.
