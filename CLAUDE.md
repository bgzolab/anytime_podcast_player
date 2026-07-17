# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

This project uses **FVM** (Flutter Version Management) pinned to Flutter `3.41.5`. Prefix all Flutter/Dart commands with `fvm`:

```bash
# Install dependencies
fvm flutter pub get

# Run the app (debug)
fvm flutter run

# Run the app with PodcastIndex search
fvm flutter run --dart-define=PINDEX_KEY=mykey --dart-define=PINDEX_SECRET=mysecret

# Run all tests
fvm flutter test

# Run a single test file
fvm flutter test test/unit/services/settings_test.dart

# Run tests with coverage
fvm flutter test --coverage
genhtml coverage/lcov.info --output coverage

# Build Android APK
fvm flutter build apk

# Build Android App Bundle
fvm flutter build appbundle

# Analyze code
fvm flutter analyze

# Format code (project uses 120 chars, not default 80)
fvm dart format --line-length 120 .

# Generate ARB files from Dart message definitions
fvm dart run intl_translation:extract_to_arb --output-dir=lib/l10n lib/l10n/L.dart

# Generate l10n Dart files from ARB translations
fvm dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/l10n/L.dart lib/l10n/intl_*.arb
```

## Architecture

Anytime is a mobile podcast player (Android & iOS) built with **Dart/Flutter**. It follows a **layered architecture** (UI → BLoC → Services → API + Repository):

### Layer structure (`lib/`)

```
lib/
├── main.dart                 # Entry point: logging, CA certs, runApp
├── ui/                       # Flutter widgets & screens
│   ├── anytime_podcast_app.dart  # Root app: provider setup, theme, nav
│   ├── themes.dart           # Light & dark theme definitions (orange accent)
│   ├── library/              # Library (subscriptions), Discovery, Downloads tabs
│   ├── podcast/              # Podcast detail, now-playing, mini player, show notes
│   ├── search/               # Search bar & results
│   ├── settings/             # Settings screens
│   └── widgets/              # 25+ reusable widgets (episode tiles, podcast tiles, etc.)
├── bloc/                     # Custom BLoC pattern (not flutter_bloc package)
│   ├── bloc.dart             # Abstract Bloc base class (resume/pause/detach)
│   ├── podcast/              # AudioBloc, EpisodeBloc, PodcastBloc, QueueBloc, OpmlBloc
│   ├── discovery/            # DiscoveryBloc (podcast charts)
│   ├── search/               # SearchBloc
│   ├── settings/             # SettingsBloc
│   └── ui/                   # PagerBloc (bottom nav tabs)
├── services/                 # Abstract interfaces + mobile implementations
│   ├── audio/                # AudioPlayerService / DefaultAudioPlayerService
│   ├── download/             # DownloadService / MobileDownloadService
│   ├── notifications/        # NotificationService / MobileNotificationService
│   ├── podcast/              # PodcastService, OPMLService
│   └── settings/             # SettingsService / MobileSettingsService
├── api/                      # External API layer
│   └── podcast/              # PodcastApi (abstract) / MobilePodcastApi (podcast_search)
├── repository/               # Persistent storage
│   ├── repository.dart       # Abstract Repository interface
│   └── sembast/              # SembastRepository (NoSQL), SembastDatabaseService
├── entities/                 # Data models: Podcast, Episode, Chapter, Transcript, Queue, etc.
├── state/                    # Shared BLoC state types (BlocLoadingState, BlocPopulatedState, etc.)
├── core/                     # Utilities: environment.dart, utils.dart, extensions.dart
├── navigation/               # NavigationRouteObserver
└── l10n/                     # Localization (10 languages: ARB files + generated Dart)
```

### Key patterns

- **Custom BLoC** (not `flutter_bloc`): extends `Bloc` base class, uses RxDart `BehaviorSubject`/`PublishSubject` for output streams. UI listens via `StreamBuilder` or `Provider.of<>()`.
- **Provider for DI**: `MultiProvider` at the root injects all BLoCs into the widget tree (`anytime_podcast_app.dart`).
- **Abstract interfaces**: Every service and API layer has a Dart abstract class with a concrete `Mobile*` implementation — enables mocking in tests.
- **Event-driven state**: BLoCs receive typed events and emit typed state objects (e.g., `BlocLoadingState`, `BlocPopulatedState`, `BlocErrorState`).
- **Sembast** for local NoSQL storage (podcasts, episodes, queue). `shared_preferences` for simple settings. An in-memory podcast cache sits over the database.

### Environment config

Compile-time constants in `lib/core/environment.dart` passed via `--dart-define`:
- `PINDEX_KEY` / `PINDEX_SECRET` — PodcastIndex.org API credentials
- `USER_AGENT` — override default user agent
- `FEEDBACK_URL` — feedback form link in app menu

### Code style

- Format: 120 character line width (`dart format --line-length 120`)
- Analyzer: `flutter_lints` recommended rules (`analysis_options.yaml`)
- Generated files: `*.g.dart` and `lib/l10n/` are excluded from analysis
