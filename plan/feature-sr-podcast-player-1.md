---
goal: Build an Android Flutter app for quick access to Sveriges Radio podcasts, starting with Radiokorrespondenterna Kina
version: 1.0
date_created: 2026-09-23
last_updated: 2026-09-23
owner: Repository maintainers
status: 'Planned'
tags: [feature, flutter, android, podcast, audio]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

This plan defines a small Android-first Flutter app that opens directly to a hardcoded Sveriges Radio podcast, initially **Radiokorrespondenterna Kina** (`https://www.sverigesradio.se/radiokorrespondenterna-kina`). The app will retrieve the selected program's episode list from Sveriges Radio's public API and play episode audio. It is a plan only; no Flutter project or application code currently exists in this repository.

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
- **CON-003**: The Sveriges Radio program page and API documentation returned HTTP 403 to the research fetcher. The public API host responded, but the retrieved broad program listing did not establish the target program's identifier or episode audio field. Verify these from the API before coding against them.
- **GUD-001**: Prefer Sveriges Radio's public API over scraping HTML. Use the canonical show page only as a user-facing fallback/source link.
- **GUD-002**: Select package versions compatible with the Flutter/Dart SDK installed when the project is created; record resolved dependencies in `pubspec.lock`. Do not use a version number copied from this plan.
- **GUD-003**: Keep API parsing and audio playback logic outside Flutter widgets so their behavior can be tested without a device.
- **PAT-001**: Follow standard Flutter conventions: application code under `lib/`, automated tests under `test/`, Android configuration under `android/`, and run `dart format`, `flutter analyze`, and `flutter test` before completion.

## 2. Implementation Steps

### Implementation Phase 1 — Create the Android Flutter scaffold

- **GOAL-001**: Establish a runnable Flutter Android project and a documented dependency baseline in the currently empty repository.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | From `/Users/ttornkvi/git/my-podcasts/`, create a Flutter project in the repository root with Android enabled, using the package name `se.sverigesradio.podcastshortcut`. Preserve the existing `plan/` directory. Confirm `pubspec.yaml`, `lib/main.dart`, `android/`, and `test/` are generated. |  |  |
| TASK-002 | Set the app display name to `SR Podcasts` using the Flutter project's Android application label configuration. Keep Android Internet access enabled using the generated manifest configuration; add no other permissions in this task. |  |  |
| TASK-003 | Select and add compatible versions of the audio playback and background audio packages to `/Users/ttornkvi/git/my-podcasts/pubspec.yaml`. Evaluate `just_audio` with `audio_service` as the default candidate; document any compatibility-based substitution in the implementation notes. Resolve packages and commit `/Users/ttornkvi/git/my-podcasts/pubspec.lock`. |  |  |

**Phase 1 completion criteria:** `flutter doctor` reports Flutter available; `flutter pub get` succeeds; the default app builds for Android; the generated project does not overwrite `/Users/ttornkvi/git/my-podcasts/plan/feature-sr-podcast-player-1.md`.

### Implementation Phase 2 — Verify Sveriges Radio data and create the data layer

- **GOAL-002**: Resolve the exact Radiokorrespondenterna Kina program record and implement tested parsing and retrieval for its current episode list.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Query Sveriges Radio's official API at `https://api.sr.se/api/v2/programs/index?format=json` using the supported search/filter parameters established from the API response or official documentation. Match the exact program title and canonical URL `https://www.sverigesradio.se/radiokorrespondenterna-kina`; verify the record's numeric program ID, podcast availability, and program image fields. Record the verified ID and evidence in `/Users/ttornkvi/git/my-podcasts/README.md`. Do not infer the ID from the page slug. |  |  |
| TASK-005 | Inspect an actual successful response from `https://api.sr.se/api/v2/episodes/index?programid={verifiedProgramId}&format=json` and determine pagination parameters, episode title/description/date/image fields, and the exact direct audio URL field that plays on Android. Follow any returned pagination links or documented limits so the latest episodes are not silently omitted. Add a sanitized representative response fixture at `/Users/ttornkvi/git/my-podcasts/test/fixtures/radiokorrespondenterna_kina_episodes.json`. |  |  |
| TASK-006 | Create `/Users/ttornkvi/git/my-podcasts/lib/models/podcast_episode.dart` with an immutable `PodcastEpisode` model and a factory that parses the verified episode response fields. Treat optional fields as nullable and reject an episode as playable only when its audio URL is absent or invalid. |  |  |
| TASK-007 | Create `/Users/ttornkvi/git/my-podcasts/lib/data/podcast_catalog.dart` with a `PodcastProgram` model and an immutable hardcoded catalog entry containing the verified program ID, `Radiokorrespondenterna Kina`, and canonical page URL. Create `/Users/ttornkvi/git/my-podcasts/lib/data/sr_api_client.dart` with a `SrApiClient` that requests and parses the target program's episode list, handles non-success HTTP responses and malformed JSON, and exposes a clear exception/error result to the UI. |  |  |
| TASK-008 | Add unit tests at `/Users/ttornkvi/git/my-podcasts/test/models/podcast_episode_test.dart` and `/Users/ttornkvi/git/my-podcasts/test/data/sr_api_client_test.dart`. Cover representative fixture parsing, optional fields, invalid/missing audio URLs, empty results, malformed responses, and HTTP errors. Inject or otherwise fake the HTTP transport so tests do not depend on live network access. |  |  |

**Phase 2 completion criteria:** The hardcoded catalog ID is backed by an exact program API record; a real current episode response confirms the parser's field mapping; all data-layer tests pass offline; API failures are represented without uncaught parsing exceptions.

### Implementation Phase 3 — Add podcast browsing and background playback

- **GOAL-003**: Implement a one-screen-first Android experience for browsing and playing the selected show's episodes.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-009 | Create `/Users/ttornkvi/git/my-podcasts/lib/audio/podcast_audio_handler.dart` with a background audio handler that uses the selected playback package, exposes play/pause/seek and episode metadata to Android system media controls, and updates playback state and queue item metadata consistently. Configure podcast-appropriate audio interruption behavior and release the player when the handler is stopped. |  |  |
| TASK-010 | Create `/Users/ttornkvi/git/my-podcasts/lib/screens/podcast_screen.dart` with a Material interface showing the hardcoded program name, available episodes, loading progress, empty state, and retryable API error state. Show episode title and available description/date; disable in-app play for episodes without a verified usable audio URL and provide the canonical show link as fallback. |  |  |
| TASK-011 | Create `/Users/ttornkvi/git/my-podcasts/lib/widgets/episode_player_controls.dart` for the current episode's play/pause, seek position, elapsed time, and duration. Reflect loading, buffering, playing, paused, and playback error states from the audio handler; avoid seeking when duration is unknown. |  |  |
| TASK-012 | Update `/Users/ttornkvi/git/my-podcasts/lib/main.dart` to initialize Flutter bindings and the background audio service before rendering the app, then open `PodcastScreen` as the initial screen. Add the Android service, notification, and media-session manifest/configuration required by the selected package's current official setup instructions; do not add a second competing background-audio plugin. |  |  |
| TASK-013 | Add widget tests at `/Users/ttornkvi/git/my-podcasts/test/screens/podcast_screen_test.dart` for loading, loaded episode list, empty/error/retry states, missing audio URL behavior, and play action delegation. Inject fake API and audio-handler dependencies so the tests run without network or native audio plugins. |  |  |

**Phase 3 completion criteria:** The app opens to the hardcoded show; users can load episodes and play a valid episode; UI reflects player state; background notification/system controls can control playback on a physical Android device or emulator that supports media playback.

### Implementation Phase 4 — Validate the Android MVP and document operation

- **GOAL-004**: Verify the complete vertical slice and document the source/API assumptions that future hardcoded shows must follow.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-014 | Add an Android integration test at `/Users/ttornkvi/git/my-podcasts/integration_test/podcast_smoke_test.dart` (and the required integration-test dependency/configuration) that starts the app with a fake SR API and fake audio source, loads the program page, and starts and pauses an episode without network access. |  |  |
| TASK-015 | Run `dart format --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, and the Android integration test where an emulator/device is available. Build a debug APK with `flutter build apk --debug`. Fix failures and record any unavailable device-only check in `/Users/ttornkvi/git/my-podcasts/README.md`. |  |  |
| TASK-016 | Complete `/Users/ttornkvi/git/my-podcasts/README.md` with prerequisites, Android run/build/test commands, Sveriges Radio API source and verification date, the program ID, known API/playback limitations, and the procedure for adding another hardcoded podcast catalog entry. |  |  |

**Phase 4 completion criteria:** Format, static analysis, and unit/widget tests pass; a debug APK builds; the network-independent smoke test passes; the README distinguishes automated checks from any unperformed device validation.

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
- **DEP-005**: A Flutter background audio/media-session package for Android foreground playback and system controls; evaluate `audio_service` with the playback package during implementation.
- **DEP-006**: Android emulator or physical Android device for end-to-end verification of audio output, background continuation, and media notification controls.

## 5. Files

- **FILE-001**: `/Users/ttornkvi/git/my-podcasts/pubspec.yaml` — Flutter package metadata, SDK constraints, runtime dependencies, and test dependencies.
- **FILE-002**: `/Users/ttornkvi/git/my-podcasts/pubspec.lock` — resolved package versions for reproducible builds.
- **FILE-003**: `/Users/ttornkvi/git/my-podcasts/lib/main.dart` — app initialization and initial route.
- **FILE-004**: `/Users/ttornkvi/git/my-podcasts/lib/models/podcast_episode.dart` — immutable episode model and JSON parsing.
- **FILE-005**: `/Users/ttornkvi/git/my-podcasts/lib/data/podcast_catalog.dart` — hardcoded curated show catalog, starting with the verified Radiokorrespondenterna Kina entry.
- **FILE-006**: `/Users/ttornkvi/git/my-podcasts/lib/data/sr_api_client.dart` — Sveriges Radio API access, decoding, and error handling.
- **FILE-007**: `/Users/ttornkvi/git/my-podcasts/lib/audio/podcast_audio_handler.dart` — playback lifecycle and Android background media controls.
- **FILE-008**: `/Users/ttornkvi/git/my-podcasts/lib/screens/podcast_screen.dart` — program episode list and loading/error/empty states.
- **FILE-009**: `/Users/ttornkvi/git/my-podcasts/lib/widgets/episode_player_controls.dart` — playback controls and progress display.
- **FILE-010**: `/Users/ttornkvi/git/my-podcasts/android/app/src/main/AndroidManifest.xml` — Android internet, background audio service, and notification/media configuration required by the chosen integration.
- **FILE-011**: `/Users/ttornkvi/git/my-podcasts/test/fixtures/radiokorrespondenterna_kina_episodes.json` — sanitized verified episode API response used by offline tests.
- **FILE-012**: `/Users/ttornkvi/git/my-podcasts/test/models/podcast_episode_test.dart` — episode model parsing tests.
- **FILE-013**: `/Users/ttornkvi/git/my-podcasts/test/data/sr_api_client_test.dart` — API client success and error tests with fake transport.
- **FILE-014**: `/Users/ttornkvi/git/my-podcasts/test/screens/podcast_screen_test.dart` — UI state and player-action widget tests.
- **FILE-015**: `/Users/ttornkvi/git/my-podcasts/integration_test/podcast_smoke_test.dart` — network-independent Android app smoke test.
- **FILE-016**: `/Users/ttornkvi/git/my-podcasts/README.md` — setup, validation, API verification evidence, and instructions for extending the curated catalog.
- **FILE-017**: `/Users/ttornkvi/git/my-podcasts/plan/feature-sr-podcast-player-1.md` — this implementation plan; preserve it during project generation and update its task status only as implementation proceeds.

## 6. Testing

- **TEST-001**: Verify `PodcastEpisode` parses the representative API fixture, optional fields, and the verified playable audio URL; verify missing or malformed audio URLs do not produce a playable episode.
- **TEST-002**: Verify the API client parses episodes, handles empty responses, malformed JSON, HTTP errors, and pagination according to the live API contract using fake HTTP responses only.
- **TEST-003**: Verify the podcast screen renders loading, success, empty, and error/retry states, and delegates play only for an episode with a usable audio URL.
- **TEST-004**: Verify the player control widget responds to fake playing, paused, buffering, unknown-duration, and error states and delegates play/pause/seek actions.
- **TEST-005**: Verify a network-independent Android integration smoke test launches the app, displays the show and episodes, starts playback through a fake source, and pauses playback.
- **TEST-006**: Verify `dart format --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` succeed. Separately verify actual background playback and Android notification controls on a device/emulator and explicitly report if that check could not be run.

## 7. Risks & Assumptions

- **RISK-001**: Sveriges Radio may change API response fields, limits, or audio URL behavior. Mitigate by verifying live responses in Phase 2, keeping parsing isolated, and retaining a sanitized contract fixture.
- **RISK-002**: Some episode audio formats or URLs may not stream on supported Android devices or may be time-limited. Validate a real current episode URL on Android and report unsupported formats as unavailable rather than treating every episode as playable.
- **RISK-003**: Android background execution and media notification requirements can vary with Android target SDK and plugin versions. Follow the selected package's current Android integration documentation and verify behavior on a device/emulator.
- **RISK-004**: The source page/API documentation was not readable by the research fetcher; program ID, exact API query behavior, and license/attribution expectations remain implementation-time verification items.
- **ASSUMPTION-001**: The requested first milestone is a single-show proof of concept that can be extended to a short curated catalog, not a full podcast directory or an independently hosted content service.
- **ASSUMPTION-002**: Sveriges Radio's public API permits this app to retrieve the selected program's public episode metadata and stream links without credentials; verify current API terms and usage guidance before release.
- **ASSUMPTION-003**: The first target can be built and tested with an available Flutter SDK and Android toolchain; this repository currently has neither a Flutter project nor a pinned toolchain.

## 8. Related Specifications / Further Reading

- Sveriges Radio target program: <https://www.sverigesradio.se/radiokorrespondenterna-kina>
- Sveriges Radio API host: <https://api.sr.se/api/v2/>
- Sveriges Radio program index API: <https://api.sr.se/api/v2/programs/index?format=json>
- Sveriges Radio episode index API pattern: <https://api.sr.se/api/v2/episodes/index?format=json>
- Flutter: <https://docs.flutter.dev/>
- Android Media3 / ExoPlayer overview: <https://developer.android.com/media/media3/exoplayer>
- `just_audio` package documentation: <https://pub.dev/packages/just_audio>
- `audio_service` package documentation: <https://pub.dev/packages/audio_service>