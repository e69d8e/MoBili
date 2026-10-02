# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

MoBili (墨哩) — a cross-platform third-party Bilibili client built with Flutter (Dart ^3.13). Release targets: Android, macOS, Windows, Linux (README has the full feature list, in Chinese). State management is `provider`, networking is `dio`. UI copy and most code comments are in Chinese; commit messages follow Conventional Commits with scopes, e.g. `feat(player): …`, `perf(memory): …`.

## Commands

- `flutter pub get` — install dependencies
- `flutter analyze` — static analysis (flutter_lints 6); CI fails on any issue, so run it before finishing
- `flutter test` — full suite (CI runs this on ubuntu-latest); feature tests in `test/*.dart`, pure units in `test/unit/`
- `flutter run` — run on a connected device or desktop target

Note: several tests call live Bilibili APIs and silently skip their network assertions when the API is unreachable, so a green `flutter test` does not verify live-API behavior end to end.

## Architecture

- `lib/main.dart` — bootstrap. Local caches/settings init through `_initSafely` (a failing initializer must never block `runApp`); network work is deferred with `unawaited`. The global `appNavigatorKey` is used by `DeepLinkService` for routing.
- `lib/services/api/` — Bilibili REST layer. All HTTP must go through the `BiliHttpClient` singleton (Dio; attaches cookies, desktop User-Agent and Referer). `BiliSecurityService` implements WBI signing (mixin key) and buvid generation. New endpoints: add the path to `api_endpoints.dart` and a per-domain `*_api_service.dart` file.
- `lib/services/player/` — playback internals: `play_stream_planner.dart` (DASH video+audio track selection), `bili_stream_proxy.dart` (local HTTP proxy with disk cache), quality-panel policy, prefetch, sleep timer, system media controls.
- `lib/services/storage/` — history, offline video cache, app cache. `lib/services/settings/` — danmaku and player settings persistence. `lib/services/update/` — GitHub release update check.
- `lib/providers/` — five ChangeNotifier providers, created in `main()` and injected into `MoBiliRoot`.
- `lib/models/` — plain data models. `lib/utils/` — `responsive_util.dart` (layout helpers), `formatters.dart`, `app_constants.dart` (version metadata), `image_decode_sizing.dart` (bitmap decode budgets).
- `lib/screens/` + `lib/widgets/` — UI. Player UI lives under `lib/widgets/player/`, listen/audio mode under `lib/widgets/audio/` (plus `screens/video/listen_video_screen.dart`).

## Conventions

- Colors: always use the semantic theme extension, e.g. `context.colors.textSub` (defined in `lib/theme/app_theme.dart`) — never branch on `isDark` or hardcode light/dark colors; AMOLED mode depends on this indirection. Spacing/typography tokens are in `lib/theme/app_dimens.dart` and `app_typography.dart`.
- Services are singletons via `static final _instance` + private constructor + `factory`.
- Version bumps must update both `pubspec.yaml` (`version:`) and `AppConstants.appVersion` / `appBuildNumber` in `lib/utils/app_constants.dart`.
- Keep the existing comment style: Chinese comments explaining constraints and rationale, English identifiers.

## Gotchas

- `kIsWeb` guards exist in networking (browsers forbid manual `Cookie` headers and custom UA). Web is not a release target, but keep the guards when touching `lib/services/api/` or player streaming.
- The image cache is deliberately large — 256MB / 1000 entries in `main.dart`, with decode budgets in `image_decode_sizing.dart` — to avoid re-decode jank on long image lists. Don't shrink it.
- `android/build.gradle.kts` and `android/settings.gradle.kts` intentionally list Aliyun maven mirrors first (direct TLS to dl.google.com / Maven Central is unreliable from mainland China). Leave them in place.
- Release signing material (`android/key.properties`, `*.jks`, `*.keystore`) must never be committed.
- `mobili_architecture*.html/png/json` are generated docs/scratch artifacts — ignore them.
