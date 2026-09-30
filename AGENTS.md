# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

**Anytime Podcast Player** — a free, open-source podcast player for Android & iOS, built with Dart/Flutter (v1.4.2).
Layered architecture: **UI → BLoC → Services → API + Repository**. Offline-first: subscriptions and episodes persist
locally; the network is only used for refreshes and searches.

## Toolchain — read this first

- Flutter is pinned with **FVM** to `3.41.5`. **Always prefix** commands with `fvm`; a bare `flutter` may pick up the wrong SDK.
- Format with **120-character** line width (not the default 80).
- Keep the code compatible with **Flutter 3.27.4** where possible: iOS ships from a separate branch because of an
  accessibility bug in later Flutter versions. `fvm flutter analyze` will report deprecation warnings as a result —
  **ignore those warnings; do not migrate the deprecated APIs.**

## Commands

```bash
fvm flutter pub get                 # install dependencies
fvm flutter run                     # run (debug)
fvm flutter test                    # run all tests
fvm flutter test test/unit/services/settings_test.dart   # run a single test file
fvm flutter test --coverage         # coverage (genhtml coverage/lcov.info --output coverage)
fvm flutter analyze                 # static analysis
fvm dart format --line-length 120 . # format
fvm flutter build apk               # Android APK
fvm flutter build appbundle         # Android App Bundle
```

Pass PodcastIndex credentials at runtime (otherwise only iTunes search is available):

```bash
fvm flutter run --dart-define=PINDEX_KEY=mykey --dart-define=PINDEX_SECRET=mysecret
```

### Localization

L10n uses `intl` + `intl_translation`, 10 supported languages (de, en, es, gl, it, nl, ru, tr, vi, zh_Hans).
Workflow: define messages in `lib/l10n/L.dart` → extract ARB → translate → generate bindings.

```bash
fvm dart run intl_translation:extract_to_arb --output-dir=lib/l10n lib/l10n/L.dart
fvm dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/l10n/L.dart lib/l10n/intl_*.arb
```

## Codebase map (`lib/`)

```
main.dart              Entry: logging → MobileSettingsService → CA certs → runApp
ui/                    Widgets/screens, no business logic
  anytime_podcast_app.dart   Root (~30 KB): MultiProvider DI, theme, MaterialApp, home nav
  library/ podcast/ search/ settings/ widgets/   Tabs, player, search, settings, 25+ widgets
bloc/                  Business logic: bloc.dart base + podcast/ discovery/ search/ settings/ ui/
services/              Abstract interface + Mobile* impl: audio/ download/ notifications/ podcast/ settings/
api/podcast/           PodcastApi (abstract) / MobilePodcastApi (podcast_search pkg)
repository/            Repository (abstract) / sembast/ NoSQL impl + DB service (versioning, migration)
entities/              Data models: Podcast, Episode, Chapter, Transcript, Queue, Person, Funding…
state/                 Shared state types: bloc_state.dart, episode_state.dart, library_state.dart…
core/                  environment.dart (compile-time constants), utils.dart, extensions.dart
l10n/                  L.dart + intl_*.arb + generated messages_*.dart
```

## Key patterns

- **Custom BLoC, not `flutter_bloc`.** Every BLoC extends the `Bloc` base class (`lib/bloc/bloc.dart`), is a
  `ChangeNotifier`, and uses RxDart `BehaviorSubject` as its output stream. Lifecycle hooks: `resume` / `pause` /
  `detach`; close subjects on dispose.
- **Provider for DI.** `MultiProvider` in `anytime_podcast_app.dart` injects all BLoCs (Search, Discovery, Episode,
  Podcast, Pager, Audio, Settings, Opml, Queue).
- **Events in, states out.** UI pushes typed events via `bloc.eventSink.add(...)` and listens with
  `Provider.of<T>(context).stateStream` / `StreamBuilder`. States extend `BlocState`
  (`BlocDefaultState` / `BlocLoadingState` / `BlocBackgroundLoadingState` / `BlocEmptyState` /
  `BlocPopulatedState<T>` / `BlocErrorState`).
- **Abstract interface + `Mobile*` implementation** for every service and API — the seam that makes mocking possible
  in tests. Keep it when adding services.
- **Sembast persistence.** Stores: `podcasts` (key: feedUrl), `episodes` (key: link), `queue`, `transcripts`. All
  reads check an in-memory `Map` cache first, then the DB (and populate the cache on miss). `shared_preferences` is
  used for simple settings only.
- **Audio pipeline:** `AudioBloc` → `DefaultAudioPlayerService` (wraps `audio_service` for background/lock-screen
  controls) → `just_audio` (engine) + `audio_session` (audio focus).
- **Deep links:** `https://anytimeplayer.app/subscribe?url=<feed>` handled via `app_links`.

### Compile-time config (`lib/core/environment.dart`, via `--dart-define`)

| Variable | Purpose | Default |
|---|---|---|
| `PINDEX_KEY` / `PINDEX_SECRET` | PodcastIndex API credentials | `''` |
| `USER_AGENT` | Override auto-generated user agent | `''` |
| `FEEDBACK_URL` | Feedback form link in the app menu | `''` (hidden) |

## Conventions

- Dart style: `snake_case.dart` files, `PascalCase` classes, `camelCase` members; imports ordered `dart:` →
  `package:` → project.
- Lint rules: `package:flutter_lints/flutter.yaml` (`analysis_options.yaml`, 120-col page width).
- **Never hand-edit generated files:** `*.g.dart`, `lib/l10n/messages_*.dart` (both are excluded from analysis).
- All user-facing strings belong in `lib/l10n/L.dart` — never hard-code UI text.
- UI changes must stay accessible on both Android **TalkBack** and iOS **VoiceOver**.
- Create new files inside this repository, not in `/tmp`.
- Tests live under `test/unit/` (core, navigation, persistence, opml, services…) with mocks in `test/unit/mocks/` and
  fixtures in `test_resources/` (`.opml`, `.rss`). Use Mockito mocks of the abstract interfaces.
- CI: `.github/workflows/dart.yml` runs pub get → test → debug APK/appbundle builds. Releases are built with Codemagic.
- CI review: `.github/workflows/opencode-review.yml` reviews non-draft PRs from `bgzo` with opencode. It inlines the
  opencode GitHub action steps so the release-version lookup is authenticated and non-fatal, and retries the review
  once (16 + 11 minute attempts) when the provider stalls. Inspect a failed run with `gh run view <run-id> --log-failed`;
  retry it with `gh run rerun <run-id>`. If both attempts fail, fall back to a manual review and record it on the PR.

## Known tech debt

- `ui/anytime_podcast_app.dart` is ~30 KB and should eventually be split.
- Migrating off the custom BLoC/Provider stack (Riverpod / flutter_bloc) is a possible long-term direction.
- Test coverage is thin (5 unit test files): widget and integration tests are missing.

## More docs

- `README.md` — product info, build-from-source, Flutter version notes.
- `CONTRIBUTING.md` — PR expectations.
- `TRANSLATION.md` — full l10n workflow for new locales.
