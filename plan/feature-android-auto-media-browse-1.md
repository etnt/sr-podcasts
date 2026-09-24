---
goal: Make the app appear in Android Auto with a browsable show list and car-controlled playback by migrating from just_audio_background to audio_service with a custom PodcastAudioHandler
version: 1.0
date_created: 2026-09-23
last_updated: 2026-09-23
owner: Repository maintainers
status: 'In progress'
tags: [feature, flutter, android, android-auto, audio, migration, podcast]
---

# Introduction

![Status: In progress](https://img.shields.io/badge/status-In%20progress-yellow)

This plan implements Option A from `/Users/ttornkvi/git/my-podcasts/plan/research-android-auto-car-screen.md`. The app migrates from `just_audio_background` to `audio_service` used directly, through one custom `PodcastAudioHandler` that serves the Android Auto browse tree (root → subscribed shows → latest episodes) and accepts playback requests from the car. The phone app keeps working exactly as today: the same `PodcastPlayer` interface, the same notification behavior, and the same test suite. One app, one APK, no car build flavor.

The result: the app appears in the car's media app list, the car renders its native browse and player screens from the app's content tree, and next/previous steps between the latest episodes of the chosen show.

## 1. Requirements & Constraints

- **REQ-001**: The app must appear in the Android Auto media app list on a connected head unit and offer a browse tree of all saved subscriptions as browsable nodes with their latest episodes as playable leaves.
- **REQ-002**: Picking an episode in the car must start playback of that episode with the show's latest-episode list as the queue, so next/previous in the car steps between episodes.
- **REQ-003**: The phone app's behavior must not regress: tapping an episode in the phone UI streams it, background playback with screen off continues, and the media notification with play/pause/seek controls keeps working.
- **REQ-004**: The phone UI must keep depending only on the `PodcastPlayer` interface (`lib/src/podcast/audio/podcast_player.dart`); the car-facing handler must not leak into presentation code.
- **REQ-005**: `just_audio_background` must be removed from `pubspec.yaml` after the migration so only one background-audio stack remains.
- **SEC-001**: Use HTTPS only, as today. Do not add Android permissions beyond the existing `INTERNET`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` set. Do not add credentials, analytics, or car-specific extras.
- **CON-001**: `audio_service` is already in the dependency tree (resolved 0.18.19 in `pubspec.lock`), so the migration adds no new native code beyond what ships today.
- **CON-002**: The handler is constructed in `main()` before `runApp`, outside the Riverpod `ProviderScope`. It must receive its dependencies (`SharedPreferences`, `SrApiClient`) as constructor arguments instead of reading Riverpod providers.
- **CON-003**: The SR API has no bulk episode endpoint per subscription list; the handler must fetch episodes lazily per show on first browse, using the existing `SrApiClient.fetchEpisodes`, and cache the result in memory.
- **CON-004**: The target is Android only. No iOS, CarPlay, or Android Automotive OS distribution work in this plan.
- **GUD-001**: Reuse the existing data layer (`SrApiClient`, `PodcastProgram`, `PodcastEpisode`, subscriptions storage) unchanged; the handler adapts it, never duplicates parsing.
- **GUD-002**: Resolve package versions with `flutter pub get` on the installed Flutter SDK (3.44.0 as of 2026-09-23); record them in `pubspec.lock`. Do not copy version numbers from this plan into code.
- **GUD-003**: Keep logic outside widgets so behavior is testable without a device, per the repo's existing test conventions (fakes under `test/fakes`).
- **PAT-001**: Follow standard Flutter conventions: code under `lib/`, tests under `test/`, run `dart format`, `flutter analyze`, and `flutter test` before completion.

## 2. Implementation Steps

### Implementation Phase 1 — Dependency swap and handler skeleton

- **GOAL-001**: Move the background-audio stack from `just_audio_background` to `audio_service` with a custom handler, keeping all phone-side behavior green.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | In `/Users/ttornkvi/git/my-podcasts/pubspec.yaml`, remove the `just_audio_background` dependency and add `audio_service: ^0.18.19` as a direct dependency. Keep `just_audio`, `audio_session`, and all other dependencies unchanged. Run `flutter pub get` and confirm `pubspec.lock` resolves without downgrading `just_audio`. | ✅ | 2026-09-23 |
| TASK-002 | Create `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_audio_handler.dart` declaring `class PodcastAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler`. Constructor parameters: `SrApiClient apiClient`, `Future<List<PodcastProgram>> Function() loadSubscriptions`. Private final fields: `final AudioPlayer _player = AudioPlayer();`, `final Map<int, List<PodcastEpisode>> _episodeCache = {};`, `final Map<String, PodcastEpisode> _episodeIndex = {};`. Do not add browse callbacks in this task. | ✅ | 2026-09-23 |
| TASK-003 | In `/Users/ttornkvi/git/my-podcasts/lib/main.dart`, replace the `JustAudioBackground.init` call with `AudioService.init(builder: () => handler, config: <config from TASK-009>)`, remove the `just_audio_background` import, and construct the handler with the already-awaited `SharedPreferences` instance and a `loadSubscriptions` closure calling `SubscriptionsNotifier.loadSubscriptions` (TASK-004). Keep `configurePodcastAudioSession()` unchanged. | ✅ | 2026-09-23 |
| TASK-004 | In `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/data/subscriptions.dart`, make subscription loading reusable without a notifier: add `static List<PodcastProgram> loadSubscriptions(SharedPreferences prefs)` that reads key `subscriptions.v1`, seeds `podcastCatalog.first` and persists on first run exactly like `build()` does today, and returns the decoded list. Refactor `build()` to call it. Decode behavior, including corrupt-entry skipping, must be identical to the current `_decode`. | ✅ | 2026-09-23 |
| TASK-005 | Replace the player used by the phone UI: add `class AudioServicePodcastPlayer implements PodcastPlayer` in `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_player.dart`. It wraps the handler-owned `AudioPlayer`; `setUrlAndPlay` loads `AudioSource.uri(audioUrl)` and updates the handler `mediaItem` stream with the same id/album/title/artist/artUri values; `playing`, `playingStream`, `positionStream`, `durationStream`, `play`, `pause`, `seek`, `dispose` forward to the same player. In `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_playback.dart`, change `podcastPlayerProvider` to construct this class over the shared handler. Delete `JustAudioPodcastPlayer`. | ✅ | 2026-09-23 |
| TASK-006 | Run the existing validation from `/Users/ttornkvi/git/my-podcasts/README.md`: `dart format --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. Fix fallout (expected: `MediaItem` import moves from `just_audio_background` to `audio_service`). The phone app must behave exactly as before: episodes play, the notification appears, all tests pass. | ✅ | 2026-09-23 |

**Phase 1 completion criteria:** `just_audio_background` is gone from `pubspec.yaml` and all imports; `AudioService.init` boots the custom handler at startup; the existing 34-test suite passes; `flutter build apk --debug` succeeds.

### Implementation Phase 2 — Browse tree and car playback

- **GOAL-002**: Serve the show → episode content tree to Android Auto and let the car start and step playback.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-007 | In `podcast_audio_handler.dart`, add media-id constants and mappers: `static const _rootId = 'root';`, ids formatted as `show:<programId>` and `episode:<episodeId>`. Add `MediaItem _programToMediaItem(PodcastProgram program)` (browsable node: `id`, `album: 'SR Podcasts'`, `title: program.name`, `artUri: program.imageUrl`) and `MediaItem _episodeToMediaItem(PodcastEpisode episode, PodcastProgram program)` (playable leaf: `id`, `album: program.name`, `title: episode.title`, `artist: program.name`, `artUri: episode.imageUrl ?? program.imageUrl`, `duration: episode.duration`). Every mapped episode is registered in `_episodeIndex` keyed by its media id. | ✅ | 2026-09-23 |
| TASK-008 | Override `getChildren(String parentMediaId, [Map<String, dynamic>? options])`: for the root, load subscriptions via the injected `loadSubscriptions` closure and return one browsable `MediaItem` per show; for a `show:<id>` parent, look the program up in that list, return cached episodes or fetch once through `apiClient.fetchEpisodes(program)`, store in `_episodeCache`, and return only playable episodes (`audioUrl != null`). On an API failure while browsing a show, return an empty list (log via `debugPrint`); the root list itself must never throw. | ✅ | 2026-09-23 |
| TASK-009 | Configure Android Auto presentation: in the `AudioServiceConfig` used by `AudioService.init` (wired in TASK-003), set `androidBrowsableRootExtras` with `AndroidContentStyle.supportedKey: true`, `browsableHintKey: AndroidContentStyle.gridItemHintValue`, `playableHintKey: AndroidContentStyle.listItemHintValue`. Set the same `CONTENT_STYLE` extras on each mapped `MediaItem.extras` so shows render as a grid and episodes as a list in the car. | ✅ | 2026-09-23 |
| TASK-010 | Override `playMediaItem(MediaItem mediaItem)`: look the media id up in `_episodeIndex`; if unknown, ignore. Load `AudioSource.uri(episode.audioUrl!)` on `_player`, publish the show's playable episodes as the queue via the `queue` stream, set `mediaItem`, update `playbackState`, and start playback. Reuse one private `Future<void> _playEpisode(PodcastEpisode episode, PodcastProgram program)` shared with `AudioServicePodcastPlayer` so the phone UI and the car drive identical state. | ✅ | 2026-09-23 |
| TASK-011 | Override `playFromMediaId(String mediaId, [Map<String, dynamic>? extras])` to resolve the id and delegate to `playMediaItem` (car hosts may use either entry point), and override `playFromSearch(String query, [Map<String, dynamic>? extras])` to match the query case-insensitively as a substring of a subscription name and start the latest playable episode of the first match; no match is a no-op. | ✅ | 2026-09-23 |
| TASK-012 | Ensure next/previous work from the car: keep `QueueHandler`'s queue logic and wire `_player` sequence state so `skipToNext`/`skipToPrevious` move within the queued episode list of the current show. Verify car-initiated playback state shows up in the phone UI streams consumed by `AudioServicePodcastPlayer` (TASK-005). | ✅ | 2026-09-23 |
| TASK-013 | Fix car discovery found missing during real-car testing (2026-09-24): Android Auto never listed the app because the manifest lacked the Android Auto media declaration. Add `/Users/ttornkvi/git/my-podcasts/android/app/src/main/res/xml/automotive_app_desc.xml` with `<automotiveApp><uses name="media"/></automotiveApp>` and a `com.google.android.gms.car.application` meta-data pointing at it in the manifest. Corrected the earlier "no manifest changes needed" assumption in FILE-007 and the research document. | ✅ | 2026-09-24 |
| TASK-014 | Diagnose v1.1.1 still not appearing after TASK-013. Inspect the published universal APK and confirm that its merged manifest contains the automotive meta-data, exported `AudioService`, and `MediaBrowserService` intent. Document that every GitHub release APK is sideloaded and therefore hidden by Android Auto until its developer setting `Unknown sources` is enabled; add the same warning to future GitHub release notes. | ✅ | 2026-09-24 |
| TASK-015 | Fix real-car browse and playback timeouts: limit the car handler to the latest SR API page instead of downloading up to the full history (896 episodes for Vetenskapsradion Historia), load only the selected URL into `just_audio`, return from car play callbacks without awaiting the episode-long `AudioPlayer.play()` future, and publish previous/play-pause/next controls for Android Auto and its dashboard card. | ✅ | 2026-09-24 |

**Phase 2 completion criteria:** a head unit (DHU or Automotive OS emulator) lists the app, shows the subscription grid, lists episodes of a show, and starts playback from the car; the phone UI reflects the same playback state.

## 3. Alternatives

- **ALT-001**: Keep `just_audio_background` and additionally register a separate hand-written Android `MediaBrowserService` in Kotlin. Rejected: two media stacks would fight for the notification and car control; `audio_service` already owns the service the manifest declares.
- **ALT-002**: Build the car UI with `flutter_carplay` Android Auto templates (Android for Cars App Library). Rejected for this app: Google steers audio apps to the media-session model; template UIs target navigation/POI/IoT categories and would be more work with guideline risk. Kept as a future escape hatch (research document, Option B).
- **ALT-003**: Do nothing; rely on the app appearing in the car's session list while playing. Rejected: the car cannot start or browse the app while stopped, failing REQ-001.

## 4. Dependencies

- **DEP-001**: `audio_service` 0.18.19 — provides `AudioService`, `BaseAudioHandler`, `QueueHandler`, `SeekHandler`, `MediaItem`, `AndroidContentStyle`. Already resolved in `pubspec.lock`; becomes a direct dependency.
- **DEP-002**: `just_audio` 0.10.x — unchanged playback engine owned by the handler.
- **DEP-003**: `audio_session` — unchanged; `configurePodcastAudioSession()` keeps configuring the speech profile.
- **DEP-004**: Existing data layer — `SrApiClient.fetchEpisodes`, `PodcastProgram`, `PodcastEpisode`, and the `subscriptions.v1` storage key; the handler consumes them without modification.
- **DEP-005**: Android Auto verification tooling — Desktop Head Unit (`sdkmanager "extras;google;auto"`) or the Android Automotive OS emulator image in Android Studio.

## 5. Files

- **FILE-001**: `/Users/ttornkvi/git/my-podcasts/pubspec.yaml` — swap `just_audio_background` for a direct `audio_service` dependency (TASK-001).
- **FILE-002**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_audio_handler.dart` — new; custom handler, media-id scheme, mappers, browse tree, car playback (TASK-002, TASK-007..TASK-012).
- **FILE-003**: `/Users/ttornkvi/git/my-podcasts/lib/main.dart` — `AudioService.init` wiring and handler construction (TASK-003, TASK-009).
- **FILE-004**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/data/subscriptions.dart` — reusable `loadSubscriptions` static helper (TASK-004).
- **FILE-005**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_player.dart` — `AudioServicePodcastPlayer` replacing `JustAudioPodcastPlayer` (TASK-005).
- **FILE-006**: `/Users/ttornkvi/git/my-podcasts/lib/src/podcast/audio/podcast_playback.dart` — `podcastPlayerProvider` construction over the shared handler (TASK-005).
- **FILE-007**: `/Users/ttornkvi/git/my-podcasts/android/app/src/main/AndroidManifest.xml` — the service, intent filter, receiver, and permissions match `audio_service`'s requirements, but Android Auto additionally requires the `com.google.android.gms.car.application` meta-data with `res/xml/automotive_app_desc.xml` (TASK-013); without it the car never lists the app.
- **FILE-008**: `/Users/ttornkvi/git/my-podcasts/test/src/podcast/audio/` — new test directory (section 6).

## 6. Testing

- **TEST-001**: `test/src/podcast/audio/podcast_audio_handler_test.dart` — handler unit tests without platform channels: root `getChildren` returns one browsable item per fake subscription; `getChildren('show:<id>')` fetches once and caches (fake `SrApiClient` hit once across two calls); unplayable episodes are filtered out; `_episodeToMediaItem` maps id, title, album, artUri fallback, and duration; an API failure yields an empty children list instead of a thrown error.
- **TEST-002**: Handler playback tests — `playMediaItem` with an indexed episode starts playback on a fake or, where CI allows, a real `just_audio` player; unknown ids are ignored; `playFromSearch` matches subscription names case-insensitively and no-ops on miss; the queue contains the show's playable episodes so `skipToNext`/`skipToPrevious` step as required by REQ-002.
- **TEST-003**: Existing suite guard — `test/fakes/fake_podcast_player.dart` stays as the fake behind the unchanged presentation tests; all 34 existing tests in `test/` must pass without behavior changes.
- **TEST-004**: Manual device verification — `flutter build apk --debug` on a device or emulator; phone flow (episode plays, screen-off playback continues, notification works) and car flow (DHU or Automotive OS emulator: app in media list, browse shows, play episode from the car, next/previous steps episodes). Record the outcome in the plan's task notes and update the README's manual-verification paragraph.

## 7. Risks & Assumptions

- **RISK-001**: Migrating the player behind `podcastPlayerProvider` can change phone behavior if the handler's `playbackState`/`mediaItem` streams are not kept in sync with `_player`. Mitigation: one shared `_playEpisode` path (TASK-010) and the existing suite (TEST-003) plus a manual phone check (TEST-004).
- **RISK-002**: `audio_service`'s browse callbacks run on the service side and are async; a slow or failing SR fetch on first browse could make the car show an empty show page. Mitigation: cache in `_episodeCache`, return empty on failure, and never throw from `getChildren` (TASK-008).
- **RISK-003**: The car host may call `playFromMediaId` instead of `playMediaItem`, or call `getChildren` for the root before subscriptions exist. Mitigation: implement both entry points (TASK-011) and always answer the root (TASK-008).
- **RISK-004**: Media-item art URLs are remote; cars with poor connectivity may show blank artwork. Accepted: images are optional in the SR API already; no artwork caching in this plan.
- **RISK-005**: GitHub release APKs are sideloaded outside Google Play. Android Auto hides sideloaded debug and release builds unless the phone's Android Auto developer setting `Unknown sources` is enabled. Mitigation: document the required setting in the README and every GitHub release.
- **ASSUMPTION-001**: SR episode ids are stable and unique across programs; the `episode:<id>` media id scheme relies on this, as does `_episodeIndex`.
- **ASSUMPTION-002**: The user's car head unit runs Android Auto (projected) or a compatible skin. The DHU verification is indicative; behavior on the user's specific car is confirmed only by TEST-004 in the real car.
- **ASSUMPTION-003**: `audio_service` 0.18.x's `BaseAudioHandler` browse surface (`getChildren`, `playFromMediaId`, `playMediaItem`, `playFromSearch`, `androidBrowsableRootExtras`) is sufficient for the car flow, as verified in the research phase against the pub-cache source.
- **ASSUMPTION-004**: `audio_service`'s default `onGetRoot` accepts system media clients; if the resolved version restricts clients, adjust the config in TASK-009 rather than adding native code.

## 8. Related Specifications / Further Reading

- `/Users/ttornkvi/git/my-podcasts/plan/research-android-auto-car-screen.md` — the research document and Option A rationale this plan implements.
- `/Users/ttornkvi/git/my-podcasts/plan/feature-sr-podcast-player-1.md` — original playback plan (REQ-004/REQ-005 behaviors that must not regress).
- `/Users/ttornkvi/git/my-podcasts/README.md` — validation commands and manual verification notes to update after TEST-004.
- `audio_service` package and Android Auto setup: https://pub.dev/packages/audio_service
- Android developers, "Media apps for cars overview": https://developer.android.com/training/cars/media
- Android Auto Desktop Head Unit testing: https://developer.android.com/training/cars/testing


