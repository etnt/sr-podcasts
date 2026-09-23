---
goal: Explore how the app can show its UI and controls on a car infotainment screen (Android Auto) from a Flutter app
version: 1.0
date_created: 2026-09-23
last_updated: 2026-09-23
owner: Repository maintainers
status: 'Research'
tags: [research, flutter, android, android-auto, audio, podcast]
---

# Research: showing this app on the car infotainment screen (Android Auto)

![Status: Research](https://img.shields.io/badge/status-Research-blue)

This document records research into making this app usable on the car screen
while driving. The Sveriges Radio app already shows up in the car. The goal is
the same behavior for this app, but with the small personal show list instead
of the full SR app flow.

Research was done on 2026-09-23 with Flutter 3.44.0. Package versions below
were verified against the resolved versions in `pubspec.lock` and the local
pub cache.

## 1. The question

The user wants the app to display on the car infotainment screen, like other
apps do, especially the official Sveriges Radio app. The user asked whether
Flutter has adaptation libraries for this.

## 2. TL;DR — the recommendation

A Flutter app cannot draw its own Flutter widgets on the Android Auto screen.
That is an Android platform rule, not a Flutter limitation. But the car does
not need our UI. Android Auto renders its **own native player and browse
screens** from the app's *media session* and *media browser service*. That is
exactly how the official SR app appears in the car.

The recommendation:

1. Keep `just_audio` as the playback engine.
2. Replace `just_audio_background` with `audio_service` used directly, through
   a custom `AudioHandler` that implements the Android Auto browse callbacks
   (`getChildren`, `playFromMediaId`, `playMediaItem`).
3. Serve the browse tree: root → subscribed shows → latest episodes.
4. No manifest changes are needed. The `MediaBrowserService` intent filter is
   already registered for `com.ryanheise.audioservice.AudioService`.

This gives the app a place in the car's media app list, a native player screen
with the current episode, a browse screen with the show list, next/previous
episode steps, and voice or steering-wheel control support. It is the lowest
risk option and stays inside official Android media app guidelines.

## 3. Background: how media apps appear on the car screen

Android Auto (projected from the phone) supports two very different app
shapes:

- **Media apps.** An audio app ships a `MediaBrowserServiceCompat` (or the
  newer `MediaLibraryService`) and a `MediaSession`. Android Auto discovers
  the service, lists the app in the car's media app list, and renders browse
  and playback screens with its own native UI. The phone app only supplies
  the content tree (`MediaItem`s with browsable/playable flags) and playback
  state. Apple CarPlay has the equivalent model for audio apps.
- **Template apps.** An app built on the Android for Cars App Library
  (`androidx.car.app`) draws content in fixed templates (list, grid, pane,
  map). This category is meant for navigation, parking, charging, and IoT
  apps. Google steers audio and podcast apps to the media app model instead.

In both shapes the car screen shows car-native UI, not the phone app's UI.
So "display the UI on the infotainment screen" for a podcast app means
"feed the car's native media UI". The official SR app does this; it is a
media app in the car's list.

Flutter's own documentation currently has **no** Android Auto or Android
Automotive page. The historical draft page
(`docs.flutter.dev/platform-integration/android/android-automotive-os`) has
been removed from the Flutter docs. The Flutter docs Android index lists no
car-related topic. Community packages fill this gap; they are covered below.

## 4. What the app has today

- Playback: `just_audio` 0.10.x with `just_audio_background` 0.0.1-beta.17.
- `just_audio_background` is internally built on `audio_service` 0.18.19.
- `android/app/src/main/AndroidManifest.xml` already contains:
  - `com.ryanheise.audioservice.AudioServiceActivity` as the launcher
    activity,
  - the `com.ryanheise.audioservice.AudioService` service with
    `android.media.browse.MediaBrowserService` intent filter and
    `mediaPlayback` foreground service type,
  - the `MediaButtonReceiver`,
  - `WAKE_LOCK`, `FOREGROUND_SERVICE`, and
    `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions.

So the car already has everything it needs to *discover* the app. What is
missing is content: the app never exposes a browse tree, so the car has
nothing to list and cannot start playback by itself.

Verified from the pub cache source of
`just_audio_background-0.0.1-beta.17`: the package implements none of the
browse callbacks. There is no `getChildren`, `subscribeToChildren`,
`playFromMediaId`, `playMediaItem`, `playFromSearch`, or `search` anywhere in
its single source file. It only forwards remote control commands (play, pause,
seek, next, previous) and media notification metadata. Its README claims
"Android Auto and CarPlay" support, but that claim covers the *player
controls*, not a browsable library.

## 5. Options evaluated

### Option A (recommended): media app via `audio_service` with a custom handler

`audio_service` 0.18.19 has first-class Android Auto support. Verified in the
pub cache source (`audio_service-0.18.19/lib/audio_service.dart`):

- `AudioHandler.getChildren(parentMediaId, options)` — supplies the browse
  tree the car displays. The service internally answers the car's
  `onGetRoot`/`onLoadChildren` calls.
- `AudioHandler.subscribeToChildren(parentMediaId)` — pushes updates when a
  parent's children change.
- `AudioHandler.playFromMediaId(mediaId)`, `playMediaItem(mediaItem)`,
  `playFromSearch(query)`, `search(query)`, `prepareFromMediaId(...)` — let
  the car start playback for an item the user picked.
- `AudioServiceConfig.androidBrowsableRootExtras` and the
  `AndroidContentStyle` constants — tell Android Auto to render items as a
  list or a grid, with the same `CONTENT_STYLE` extras the official Android
  docs describe.
- The `queue` stream drives next/previous in the car.

`just_audio_background` is a thin wrapper around `audio_service` that locks
you to its default handler. Migrating means moving from
`JustAudioBackground.init` to `AudioService.init` with a custom
`PodcastAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler`
that owns a `just_audio` `AudioPlayer` internally. The player code already
sits behind the `PodcastPlayer` interface in
`lib/src/podcast/audio/podcast_player.dart`, so the UI and tests keep working
with a different implementation behind that interface.

Proposed browse tree:

```
root (browsable, CONTENT_STYLE: grid for children)
├── Radiokorrespondenterna Kina (browsable, one node per subscription)
│   └── Latest N episodes (playable leaves, list style)
```

- The queue for next/previous is the episode list of the show the user
  started. This matches the driving use case: tap show, get latest episodes,
  step between them.
- `playFromSearch` can be a simple substring match over the subscription
  names, so "Play Radiokorrespondenterna" works.

Estimated effort: a focused feature. Custom handler (~200–300 lines), browse
tree builder that reuses the existing `SrApiClient` episode fetch, replace
`just_audio_background` initialization in `main.dart`, extend the
`PodcastPlayer` fake for tests, plus device verification.

Testing: Google ships the **Desktop Head Unit (DHU)** for Android Auto
testing (`sdkmanager "extras;google;auto"`), and the **Android Automotive OS
emulator** image in Android Studio. Both render the media app list exactly as
a car does, so no real car is needed to develop and verify this.

Caveats:

- `audio_service` is stable and widely used (1.3k likes, updated 2026-07),
  but the migration is the largest code change of the options here.
- The browse callbacks are only called by the system (car, Wear OS,
  Bluetooth). On the phone itself nothing changes visually.
- The car needs at least one playable episode list before it treats the app
  as useful; an empty browse tree can make the car drop the app from the
  list. Seed from the saved subscriptions and fetch episodes lazily per
  show.

### Option B: `flutter_carplay` (Android for Cars App Library templates)

`flutter_carplay` 1.6.5 (updated 2026-08, MIT, 183 likes) supports both
CarPlay and, since v1.5.0, Android Auto through template UIs: alert, grid,
list, and tab bar templates. It renders these templates on the car screen via
the Android for Cars App Library; the Flutter code drives the templates.

Why not the primary choice for this app:

- Google's guidance puts **audio and podcast apps on the media app model**
  (Option A). The Car App Library is for navigation, POI, IoT, and similar
  categories. A custom template UI for a podcast player fights the platform
  and reads worse in the car than the native media UI.
- The Android Auto side of the package is new (v1.5.0, mid-2026), while its
  CarPlay side is the mature part. This app is Android-only.
- More work: a second UI to design and maintain, in a restricted template
  language, next to the Flutter UI.

It remains the escape hatch if the app ever needs a *custom* car screen
beyond browse and play, for example a two-tap "resume last episode" home
template.

### Option C: the `android_auto` package (0.1.3) — not applicable

A brand-new package (published 2026-09) that **embeds an Android Auto head
unit inside a Flutter app** by decoding the projected video protocol
(aasdk-based) into a Flutter `Texture`. Despite the name, it is the opposite
of what is needed: it turns a device *into a car screen that hosts a phone*,
for people building custom head units. It is Linux-first, GPL-3.0
(copy-left, viral for any app shipping it), and days old with 0 likes. Do not
use it for this app. Listed here only to prevent confusion in pub.dev search
results.

### Option D: Android Automotive OS (AAOS) — out of scope

AAOS is the Android build baked into cars (Volvo/Polestar, some Renault and
others). It is a separate distribution channel: apps are installed on the
head unit itself, via its app store, and distributed as a separate APK/AAB
with a `car` hardware declaration. Flutter can technically run on AAOS
because it is Android, and Google once had a draft Flutter doc for it (now
removed), but for this personal project the projected path via the phone is
the one that matches the user's car and the SR app's behavior.

### Does the phone app still work as today? (single app, no two versions)

Yes. Option A produces one app and one APK. There is no separate car build or
flavor to maintain. The reasons, checked against the current code:

- The phone UI never touches `just_audio_background` except through the
  `PodcastPlayer` interface (`lib/src/podcast/audio/podcast_player.dart`).
  `JustAudioPodcastPlayer` wraps a plain `just_audio` `AudioPlayer`; the only
  package-specific piece inside is the `MediaItem` tag on the audio source.
  A new `AudioServicePodcastPlayer` behind the same interface behaves
  identically from the UI's point of view.
- The car integration is passive. The extra `getChildren` and
  `playFromMediaId` callbacks sit on the audio handler and are called only by
  system media clients (the car, Wear OS, Bluetooth). Nothing in the phone UI
  calls them, and the phone UI cannot tell they exist.
- Background playback, the media notification, lock screen controls, and
  headset buttons come from the same `audio_service` machinery the app uses
  today. `just_audio_background` is only a wrapper around it; the manifest
  service `com.ryanheise.audioservice.AudioService` stays exactly as it is,
  so the phone-side playback stack does not change underneath the app.
- The 34 existing unit and widget tests keep running against fakes of the
  same `PodcastPlayer` interface. Only the initialization in `main.dart`
  swaps (`JustAudioBackground.init` → `AudioService.init` with the custom
  handler).

The one honest difference: the notification is rendered by
`audio_service`'s default configuration rather than
`just_audio_background`'s wrapper around the same thing. In practice it shows
the same title, art, and play/pause/skip actions; verify it by hand during
migration, as the existing manual playback check in the README already does.

### Option E: keep as-is

With the current setup the app may appear in the car's media session list
while it is actively playing, because the manifest already declares the media
browser service. But it cannot be started or browsed from the car while
stopped, and the browse surface is empty. That fails the goal.

## 6. Recommended implementation sketch

Not a commitment, just the shape of the work, so it can become the next
feature plan:

| Task | Description |
|------|-------------|
| 1 | Swap `just_audio_background` for `audio_service` in `pubspec.yaml` and move `JustAudioBackground.init` in `lib/main.dart` to `AudioService.init` with a new `PodcastAudioHandler`. |
| 2 | Implement `PodcastAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler`: own a `just_audio` `AudioPlayer`, forward `play/pause/seek/stop/skipToNext/skipToPrevious` from the queue. |
| 3 | Implement `getChildren`: root → one browsable node per saved subscription (id = subscription id, image from the subscription record); children of a show → latest episodes as playable `MediaItem`s with title, duration, art URI, and the `listenpodfile.url` as the playable source. |
| 4 | Implement `playFromMediaId`/`playMediaItem` to resolve a media id back to an episode and start playback with the full episode list as the queue. Keep a small in-handler map from media id to episode. |
| 5 | Set `androidBrowsableRootExtras` with `AndroidContentStyle` hints (grid for shows, list for episodes) and fill `MediaItem.extras` the same way. |
| 6 | Keep the `PodcastPlayer` interface contract; add an integration point so the in-app UI and the car handler drive the same playback state (both read the same handler streams). |
| 7 | Update tests: replace the fake background init, add handler unit tests with fakes, keep `dart format`, `flutter analyze`, `flutter test` green. |
| 8 | Verify with the Android Auto Desktop Head Unit and/or the Android Automotive OS emulator: app appears in the media list, browse works, playback starts from the car, next/previous steps episodes, notification still works. |

Design constraints carried from the existing plan docs:

- Keep the SR API layer (`SrApiClient`) unchanged and reusable for lazy
  episode fetches in the browse tree.
- Keep the current phone UI untouched; the car integration is additive.
- No new Android permissions beyond the existing media playback set.
- Follow the repo rule of simple sentences in user-facing docs if the README
  gains a section about car use.

## 7. Open questions

- Should the car browse tree mirror *all* saved subscriptions or only a
  user-chosen "car list"? Start with all subscriptions; they are already the
  short list.
- Should `playFromSearch` also search episode titles, or only show names?
  Show names are enough for driving.
- Does the user's car head unit run Google's Android Auto (projected) or a
  manufacturer skin? The media app model works on both, but the DHU test
  should be treated as indicative, not as proof the user's specific car
  behaves identically.
- Longer term: remember the last played episode and its position so the car
  can offer "resume" (the app currently does not store playback position).

## 8. Sources

Checked 2026-09-23:

- Flutter docs, Android platform integration index (no Android Auto or
  Automotive page listed; historical draft page returns HTTP 404):
  https://docs.flutter.dev/platform-integration/android
- `audio_service` 0.18.19 package README ("Android Auto, Apple CarPlay"
  support row) and local pub-cache source for `getChildren`,
  `subscribeToChildren`, `playFromMediaId`, `AndroidContentStyle`:
  https://pub.dev/packages/audio_service
- `just_audio_background` 0.0.1-beta.17 README and local pub-cache source
  (no browse callbacks implemented):
  https://pub.dev/packages/just_audio_background
- `flutter_carplay` 1.6.5 README (CarPlay and Android Auto templates,
  Android Auto templates added in v1.5.0):
  https://pub.dev/packages/flutter_carplay
- `android_auto` 0.1.3 README (head-unit-in-Flutter, Linux, GPL-3.0):
  https://pub.dev/packages/android_auto
- Android developers: "Media apps for cars overview" (MediaBrowserService /
  MediaLibraryService, browsable/playable flags, browse tree):
  https://developer.android.com/training/cars/media (page updated
  2026-08-17)


