# berdikari-mobile

Flutter mobile client for the **Berdikari ERP** — a mobile-first ERP for Indonesian UMKM. Consumes the existing stateless Laravel API (`berdikari-api`); all end-user copy is in **Bahasa Indonesia**.

Implementation plan: `docs/16-mobile-implementation-plan.md` in the main berdikari repo.

## Architecture

Layered per Flutter's recommended approach (UI / Data / optional Domain), MVVM with `ChangeNotifier` ViewModels:

```
lib/
├── config/        # Env (--dart-define), constants
├── data/
│   ├── models/    # API models
│   ├── services/  # ApiClient (http), TokenStorage — the only HTTP/storage touchpoints
│   └── repositories/  # 1:1 with the web app's Pinia stores (reference implementation)
├── domain/        # Clean models + use cases (only when logic is cross-repo)
├── routing/       # go_router
├── l10n/          # ARB (Bahasa Indonesia) + generated localizations
└── ui/
    ├── core/      # Theme tokens (ported from berdikari-web Tailwind), shared widgets
    └── features/<feature>/{view_models,views,widgets}/
```

Hard rules (from the Project DNA):
- Bahasa Indonesia for every user-facing string — via `l10n`, never hardcoded English.
- Touch targets ≥ 44×44 dp.
- API contracts are immutable — the app adapts to the API.
- RBAC deny-by-default: navigation and actions derive from the user's `permissions[]`.

## Getting started

```sh
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1   # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1  # iOS simulator
```

The local API runs from the main berdikari repo via Docker Compose (`docker compose up`).

Without an SDK on the host, use the Flutter Docker image:

```sh
docker run --rm -v "$PWD":/work -w /work ghcr.io/cirruslabs/flutter:stable flutter test
```

## Remote Config (optional)

`lib/config/remote_config_service.dart` can repoint an already-installed build (e.g. a demo APK
handed to pilot testers) at a different `API_BASE_URL` without a rebuild, via Firebase Remote
Config. Until it's set up, it fails silently and the compile-time `--dart-define=API_BASE_URL`
default (see above) stays in effect — nothing breaks if you skip this section.

**One-time setup** (needs your own Firebase login — not automatable from here):

```sh
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

Pick or create a Firebase project, register the app (`com.berdikari.berdikari_mobile`). This
generates `android/app/google-services.json` and/or `ios/Runner/GoogleService-Info.plist` and
wires the platform build files — both gitignored, keep them local.

In the Firebase console → **Remote Config**, add a String parameter named `api_base_url`
(default: empty, meaning "keep using the compile-time default"). Publish a value, e.g.
`https://berdikari-api.fly.dev/api/v1`, to repoint installed builds without shipping a new APK.

The app fetches on every cold start (min fetch interval: 1h in release builds, none in debug) and
only applies a non-empty value.

## Debugging on an emulator

Before running `scripts/distribute_demo.sh`, verify the build on an emulator:

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) and
   [Android Studio](https://developer.android.com/studio) (bundles the Android SDK, `adb`, and
   the emulator).
2. Android Studio → More Actions → Virtual Device Manager → Create Device → pick a phone profile
   and a system image (API 34+ recommended).
3. `flutter doctor` — if it flags Android licenses, run `flutter doctor --android-licenses`.
4. Launch the AVD, then from this directory:
   ```sh
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
   ```
   (`10.0.2.2` is the emulator's alias for your host machine, reaching the API from
   `docker compose up` in the main repo.)
5. While running: `r` hot reload, `R` hot restart, `q` quit. Use the VS Code Flutter extension or
   Android Studio's debugger (attach to the same `flutter run` session) for breakpoints.

## Quality gates

```sh
flutter analyze
flutter test
```

CI (GitHub Actions) runs both on every PR and push to `main`. Releases are SemVer git tags (`v0.x.y`); bump `version:` in `pubspec.yaml` in the same PR.

## Workflow

- Trunk-based: `main` is protected; work in `feat/<area>` / `fix/<area>` branches, squash-merge via PR.
- Conventional Commits (`feat:`, `fix:`, `chore:`, `test:` …).

## Demo distribution

`scripts/distribute_demo.sh` builds a signed release APK locally and pushes it to Firebase App
Distribution for pilot/demo testers (e.g. the Angkringan stakeholders). No CI involved — you run
it from your own machine (Git Bash on Windows, or a normal shell on macOS/Linux/WSL).

**One-time setup:**

1. **Generate a release keystore** (keep it outside the repo, e.g. a password manager or secure
   storage — never commit it):
   ```sh
   keytool -genkey -v -keystore berdikari-release.keystore -alias berdikari \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   Copy `android/key.properties.example` to `android/key.properties` and fill in the real
   `storeFile` path and passwords (both gitignored already).
2. **Create a Firebase project** (or reuse one), register the Android app with application ID
   `com.berdikari.berdikari_mobile`, and create a tester group named `demo-testers` under App
   Distribution with the pilot testers' emails. Copy the Android app ID (format
   `1:xxxxx:android:xxxxx`) from Project settings.
3. **Install the Firebase CLI and log in** (once):
   ```sh
   npm install -g firebase-tools
   firebase login
   ```

**Running it:**
```sh
export FIREBASE_APP_ID=1:xxxxxxxxxxxx:android:xxxxxxxxxxxxxxxx
./scripts/distribute_demo.sh "Optional release notes for this build"
```
Testers in the `demo-testers` group get an email/notification from Firebase with an install link.

The build points at `https://berdikari-api.fly.dev/api/v1` by default (the demo backend). Override with
`export API_BASE_URL=...` before running the script if testers should hit a different backend.

**Rollback:** nothing is automated or persistent — each run is a one-off local build+upload. To
stop distributing, just don't run the script again; nothing touches the Play Store or any
production release track.
