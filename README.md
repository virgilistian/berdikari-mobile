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

## Quality gates

```sh
flutter analyze
flutter test
```

CI (GitHub Actions) runs both on every PR and push to `main`. Releases are SemVer git tags (`v0.x.y`); bump `version:` in `pubspec.yaml` in the same PR.

## Workflow

- Trunk-based: `main` is protected; work in `feat/<area>` / `fix/<area>` branches, squash-merge via PR.
- Conventional Commits (`feat:`, `fix:`, `chore:`, `test:` …).
