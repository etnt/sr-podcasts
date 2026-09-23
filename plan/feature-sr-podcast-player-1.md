---
goal: Build an Android Flutter app for quick access to Sveriges Radio podcasts, starting with Radiokorrespondenterna Kina
version: 1.0
date_created: 2026-09-23
last_updated: 2026-09-23
owner: Repository maintainers
status: 'Completed'
tags: [feature, flutter, android, podcast, audio]
---

# Introduction

![Status: Completed](https://img.shields.io/badge/status-Completed-brightgreen)

This plan records implementation of a small Android-first Flutter app that opens directly to the hardcoded Sveriges Radio podcast **Radiokorrespondenterna Kina** (`https://www.sverigesradio.se/radiokorrespondenterna-kina`). The app retrieves episode metadata from Sveriges Radio's public API and streams episode audio with Android background media controls. The implementation and validation tasks below were completed on 2026-09-23.

## 1. Requirements & Constraints

- **REQ-001**: The first app release must provide direct access to Radiokorrespondenterna Kina without requiring the user to search for the show.
- **REQ-002**: The initial catalog must contain one hardcoded show entry. Store its display name, canonical Sveriges Radio page URL, and verified API program identifier in one catalog definition so additional shows can later be added in the same format.
- **REQ-003**: Retrieve the show's current episodes and playable audio URLs from Sveriges Radio at runtime; do not commit episode lists or audio URLs as static content.
- **REQ-004**: Display episode title and available episode description/date, and provide play, pause, seek, current-time, and duration controls for an episode with a valid audio URL.
- **REQ-005**: Continue audio playback with Android screen off or while the app is backgrounded, and expose system media notification controls and metadata.
- **REQ-006**: Show loading, empty, and recoverable error states for episode retrieval and playback. Keep the show page URL available as an external fallback when an episode cannot be played in-app.
- **SEC-001**: Use HTTPS for API, page, image, and media requests. Request only Android permissions required by the chosen playback integration; do not add credentials, analytics, or unrelated permissions.
- **CON-001**: The repository currently contains no tracked source files, Flutter project, dependency manifest, or prior implementation conventions. Create the Flutter project and choose a minimal, maintainable structure.
- **CON-002**: The target for the initial release is Android. Do not add iOS-specific behavior or claim cross-platform validation in this plan.
- **CON-003**: The Sveriges Radio public program page and RSS endpoint returned HTTP 403 to the research fetcher. The target record and episode/audio contract were independently verified through the official public API endpoints before implementation.
- **GUD-001**: Prefer Sveriges Radio's public API over scraping HTML. Use the canonical show page only as a user-facing fallback/source link.
- **GUD-002**: Select package versions compatible with the Flutter/Dart SDK installed when the project is created; record resolved dependencies in `pubspec.lock`. Do not use a version number copied from this plan.
- **GUD-003**: Keep API parsing and audio playback logic outside Flutter widgets so their behavior can be tested without a device.
- **PAT-001**: Follow standard Flutter conventions: application code under `lib/`, automated tests under `test/`, Android configuration under `android/`, and run `dart format`, `flutter analyze`, and `flutter test` before completion.

## 2. Implementation Steps

### Implementation Phase 1 — Create the Android Flutter scaffold

- **GOAL-001**: Establish a runnable Flutter Android project and a documented dependency baseline in the currently empty repository.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | From `/Users/ttornkvi/git/my-podcasts/`, create a Flutter project in the repository root with Android enabled, using package name `se.sverigesradio.podcastshortcut`. Preserve the existing `plan/` directory. Confirm `pubspec.yaml`, `lib/main.dart`, `android/`, and `test/` are generated. | ✅ | 2026-09-23 |
| TASK-002 | Set the app display name to `SR Podcasts` using `/Users/ttornkvi/git/my-podcasts/android/app/src/main/AndroidManifest.xml`. Keep Android Internet access enabled and add only the background media playback permissions required by the selected package. | ✅ | 2026-09-23 |
| TASK-003 | Select compatible playback/state/network dependencies in `/Users/ttornkvi/git/my-podcasts/pubspec.yaml`. Use `just_audio` with `just_audio_background` for the single-player Android MVP, `audio_session` for podcast interruption behavior, Riverpod for asynchronous state, `http` for injectable API requests, and `url_launcher` for fallback links. Resolve packages in `/Users/ttornkvi/git/my-podcasts/pubspec.lock`. | ✅ | 2026-09-23 |

**Phase 1 completion criteria:** `flutter doctor` reports Flutter available; `flutter pub get` succeeds; the app builds for Android; the generated project preserves `/Users/ttornkvi/git/my-podcasts/plan/feature-sr-podcast-player-1.md`.

### Implementation Phase 2 — Verify Sveriges Radio data and create the data layer

- **GOAL-002**: Resolve the exact Radiokorrespondenterna Kina program record and implement tested parsing and retrieval for its current episode list.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Query the official program record endpoint `https://api.sr.se/api/v2/programs/5386?format=json`; verify ID `5386`, exact name `Radiokorrespondenterna Kina`, canonical URL, podcast flag, and image. Record the live verification in `/Users/ttornkvi/git/my-podcasts/README.md`. | ✅ | 2026-09-23 |
| TASK-005 | Inspect successful responses from `https://api.sr.se/api/v2/episodes/index?programid=5386&format=json&size=100`. Parse title, description, page URL, publication date, image, duration, and `listenpodfile.url`; follow the `pagination.nextpage` links on HTTPS `api.sr.se`. Verify a returned MP3 responds with `200 audio/mpeg`. Store one sanitized actual episode fixture at `/Users/ttornkvi/git/my-podcasts/test/fixtures/radiokorrespondenterna_kina_episodes.json`. | ✅ | 2026-09-23 |
| TASK-006 | Create immutable episode and program models at `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/domain/podcast_episode.dart` and `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/domain/podcast_program.dart`. Parse optional fields as nullable and treat absent/non-HTTPS audio URLs as unplayable. | ✅ | 2026-09-23 |
| TASK-007 | Create the catalog at `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/data/podcast_catalog.dart` and API client at `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/data/sr_api_client.dart`. Parse the verified API shape; handle HTTP, JSON, episode parsing, pagination-loop, and unsafe pagination URL errors. | ✅ | 2026-09-23 |
| TASK-008 | Add tests in `/Users/ttornkvi/git/my-podcasts/test/src/podcast/domain/podcast_episode_test.dart` and `/Users/ttornkvi/git/my-podcasts/test/src/podcast/data/sr_api_client_test.dart`. Cover fixture parsing, optional fields, invalid/missing audio URLs, pagination, empty results, malformed responses, and HTTP errors using fake HTTP responses. | ✅ | 2026-09-23 |

**Phase 2 completion criteria:** The hardcoded catalog ID is backed by an exact program API record; a real current episode response confirms the parser's field mapping; all data-layer tests pass offline; API failures are represented without uncaught parsing exceptions.

### Implementation Phase 3 — Add podcast browsing and background playback

- **GOAL-003**: Implement a one-screen-first Android experience for browsing and playing the selected show's episodes.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-009 | Implement playback using `just_audio` and `just_audio_background` in `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_playback.dart`. Publish episode metadata to Android media controls, configure podcast speech audio-session behavior, expose player state, and dispose of the player. | ✅ | 2026-09-23 |
| TASK-010 | Implement `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/presentation/podcast_screen.dart` with Material 3 program/episode UI, loading/empty/retryable error states, and external show/episode fallback links. Show available episode metadata and route playable episode actions to the player. | ✅ | 2026-09-23 |
| TASK-011 | Implement `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/presentation/widgets/episode_player_controls.dart` with play/pause, seek, elapsed time, duration, loading, and playback error display. Disable seeking when duration is unknown. | ✅ | 2026-09-23 |
| TASK-012 | Initialize Flutter bindings, background playback, and podcast audio session in `/Users/ttornkvi/git/my-podcasts/lib/main.dart`; open `PodcastScreen`. Configure Android Internet, foreground media service, media button receiver, and wake-lock manifest entries in `/Users/ttornkvi/git/my-podcasts/android/app/src/main/AndroidManifest.xml`. | ✅ | 2026-09-23 |
| TASK-013 | Add widget tests at `/Users/ttornkvi/git/my-podcasts/test/src/podcast/presentation/podcast_screen_test.dart` for program/loading, fetched episodes, empty response, retry recovery, and the external SR page action using fake HTTP responses. | ✅ | 2026-09-23 |

**Phase 3 completion criteria:** The app opens to the hardcoded show; users can load episodes and play a valid episode; UI reflects player state; a real episode continues in the background on an Android emulator and the media notification is available. Physical-device validation remains a pre-release check.

### Implementation Phase 4 — Validate the Android MVP and document operation

- **GOAL-004**: Verify the complete vertical slice and document the source/API assumptions that future hardcoded shows must follow.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-014 | Install `/Users/ttornkvi/git/my-podcasts/build/app/outputs/flutter-apk/app-debug.apk` on the Android 14 Pixel emulator. Launch the app, confirm the live SR episode list renders, start a current MP3, and verify its Android media notification and controls appear. Record that the emulator was used and no physical device was available in `/Users/ttornkvi/git/my-podcasts/README.md`. | ✅ | 2026-09-23 |
| TASK-015 | Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, and the emulator launch/playback smoke test. Fix failures and distinguish emulator checks from physical-device validation in `/Users/ttornkvi/git/my-podcasts/README.md`. | ✅ | 2026-09-23 |
| TASK-016 | Complete `/Users/ttornkvi/git/my-podcasts/README.md` with prerequisites, Android run/build/test commands, verified Sveriges Radio API source and verification date, program ID, API/playback limitations, and how to add another catalog entry. | ✅ | 2026-09-23 |

**Phase 4 completion criteria:** Format, static analysis, unit/widget tests, and debug APK build pass; a live-data playback smoke test succeeds on an Android emulator; the README distinguishes emulator testing from physical-device validation. A network-independent instrumentation smoke test (`flutter test integration_test -d <device-id>`, offline fake API and fake player) was added and passes on the emulator.

## 3. Alternatives

- **ALT-001**: Scrape the Sveriges Radio program page for episode data. Rejected because page HTML is not a stable app data contract and the page returned HTTP 403 to the research fetcher; use the public API instead and verify its live schema.
- **ALT-002**: Hardcode episode titles and audio URLs. Rejected because episode metadata changes over time and media URLs may expire or change; only the initial program catalog entry is hardcoded.
- **ALT-003**: Open the Sveriges Radio page in a WebView or external browser instead of implementing playback. Rejected for the MVP because it does not provide the requested quick in-app access or app-controlled background playback; retain the canonical page as a fallback link.
- **ALT-004**: Build a general podcast subscription/search manager. Deferred because the user requested a small curated list for quick access; keep the catalog model extensible without implementing catalog editing, search, or user accounts.

## 4. Dependencies

- **DEP-001**: Flutter SDK and Dart SDK installed on the implementation host, with Android SDK/build tools configured.
- **DEP-002**: Sveriges Radio public API at `https://api.sr.se/api/v2/`; implementation depends on verifying current program lookup, episode pagination, and audio URL behavior before finalizing the client.
- **DEP-003**: A Flutter HTTP client package compatible with the selected SDK, used through an injectable transport for offline tests.
- **DEP-004**: A Flutter audio playback package capable of streaming the verified SR audio format on Android; evaluate `just_audio` during implementation.
- **DEP-005**: `just_audio_background` layered on `audio_service` for Android foreground playback and system controls in this single-player MVP.
- **DEP-006**: Android emulator or physical Android device for end-to-end verification of audio output, background continuation, and media notification controls.

## 5. Files

- **FILE-001**: `/Users/ttornkvi/git/my-podcasts/pubspec.yaml` — Flutter package metadata, SDK constraints, runtime dependencies, and test dependencies.
- **FILE-002**: `/Users/ttornkvi/git/my-podcasts/pubspec.lock` — resolved package versions for reproducible builds.
- **FILE-003**: `/Users/ttornkvi/git/my-podcasts/lib/main.dart` — app initialization and initial route.
- **FILE-004**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/domain/podcast_episode.dart` — immutable episode model and JSON parsing.
- **FILE-005**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/domain/podcast_program.dart` — immutable program model.
- **FILE-006**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/data/podcast_catalog.dart` — hardcoded curated show catalog, starting with the verified Radiokorrespondenterna Kina entry.
- **FILE-007**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/data/sr_api_client.dart` — Sveriges Radio API access, decoding, pagination, and error handling.
- **FILE-008**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_playback.dart` — playback lifecycle and Android background media controls.
- **FILE-009**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/presentation/podcast_screen.dart` — program episode list and loading/error/empty states.
- **FILE-010**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/presentation/widgets/episode_player_controls.dart` — playback controls and progress display.
- **FILE-011**: `/Users/ttornkvi/git/my-podcasts/test/fixtures/radiokorrespondenterna_kina_episodes.json` — sanitized verified episode API response used by offline tests.
- **FILE-012**: `/Users/ttornkvi/git/my-podcasts/test/src/podcast/domain/podcast_episode_test.dart` — episode model parsing tests.
- **FILE-013**: `/Users/ttornkvi/git/my-podcasts/test/src/podcast/data/sr_api_client_test.dart` — API client success and error tests with fake transport.
- **FILE-014**: `/Users/ttornkvi/git/my-podcasts/test/src/podcast/presentation/podcast_screen_test.dart` — UI state and retry widget tests.
- **FILE-015**: `/Users/ttornkvi/git/my-podcasts/README.md` — setup, validation, API verification evidence, and instructions for extending the curated catalog.
- **FILE-016**: `/Users/ttornkvi/git/my-podcasts/plan/feature-sr-podcast-player-1.md` — this implementation plan; preserve it and update task status as implementation proceeds.

## 6. Testing

- **TEST-001**: Verify `PodcastEpisode` parses the representative API fixture, optional fields, and the verified playable audio URL; verify missing or malformed audio URLs do not produce a playable episode.
- **TEST-002**: Verify the API client parses episodes, handles empty responses, malformed JSON, HTTP errors, and pagination according to the live API contract using fake HTTP responses only.
- **TEST-003**: Verify the podcast screen renders loading, success, empty, and error/retry states, and delegates play only for an episode with a usable audio URL.
- **TEST-004**: Verify the player control widget responds to fake playing, paused, buffering, unknown-duration, and error states and delegates play/pause/seek actions.
- **TEST-005**: Verify on the Android 14 Pixel emulator that the debug APK launches, retrieves live SR episodes, starts a real MP3, and displays Android media notification controls.
- **TEST-006**: Verify `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` succeed. Physical-device playback remains a pre-release check.

## 7. Risks & Assumptions

- **RISK-001**: Sveriges Radio may change API response fields, limits, or audio URL behavior. Mitigate by verifying live responses in Phase 2, keeping parsing isolated, and retaining a sanitized contract fixture.
- **RISK-002**: Some episode audio formats or URLs may not stream on supported Android devices or may be time-limited. Validate a real current episode URL on Android and report unsupported formats as unavailable rather than treating every episode as playable.
- **RISK-003**: Android background execution and media notification requirements can vary with Android target SDK and plugin versions. Follow the selected package's current Android integration documentation and verify behavior on a device/emulator.
- **RISK-004**: The source page and RSS/API documentation were not readable by the research fetcher. The program and stream details were independently confirmed through the live official API; license/attribution expectations still require review before public release.
- **ASSUMPTION-001**: The requested first milestone is a single-show proof of concept that can be extended to a short curated catalog, not a full podcast directory or an independently hosted content service.
- **ASSUMPTION-002**: Sveriges Radio's public API permits this app to retrieve the selected program's public episode metadata and stream links without credentials; verify current API terms and usage guidance before release.
- **ASSUMPTION-003**: Flutter and Android SDK installations on the implementation host are sufficient for local builds; no Flutter SDK version is pinned in the repository, so future builds may resolve different compatible package versions.

## 8. Related Specifications / Further Reading

- Sveriges Radio target program: <https://www.sverigesradio.se/radiokorrespondenterna-kina>
- Sveriges Radio API host: <https://api.sr.se/api/v2/>
- Sveriges Radio program index API: <https://api.sr.se/api/v2/programs/index?format=json>
- Sveriges Radio episode index API pattern: <https://api.sr.se/api/v2/episodes/index?format=json>
- Flutter: <https://docs.flutter.dev/>
- Android Media3 / ExoPlayer overview: <https://developer.android.com/media/media3/exoplayer>
- `just_audio` package documentation: <https://pub.dev/packages/just_audio>
- `audio_service` package documentation: <https://pub.dev/packages/audio_service>