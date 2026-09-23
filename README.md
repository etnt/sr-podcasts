# My favourite Sveriges Radion podcasts

I find it somewhat cumbersome to find the podcast I want to listen to via Sveriges Radio
app; especially when in my car. This is a mobile Android-first app that hardcodes them
for quick and easy access.

## Current app

The Android-first Flutter app currently opens **Radiokorrespondenterna Kina**.
It loads episodes from the Sveriges Radio public API and streams available MP3
files, including in the background with Android media notification controls.

### Sveriges Radio API verification

- Program: Radiokorrespondenterna Kina
- Program ID: `5386`
- Program record URL: <https://api.sr.se/api/v2/programs/5386?format=json>
- Episode endpoint: <https://api.sr.se/api/v2/episodes/index?programid=5386&format=json>
- Verified episode audio field: `episodes[].listenpodfile.url`
- The episode endpoint is paginated and returns a `pagination.nextpage` URL.
  The app requests pages of 100 episodes and follows HTTPS pagination links only on `api.sr.se`.
- Verified using the live API on 2026-09-23. One returned MP3 URL responded with `200 audio/mpeg`.
- The SR page and RSS host blocked automated inspection during implementation;
  the app uses the official API and the canonical show page link rather than scraping HTML.
- Android 14 Pixel emulator smoke test: app launched, live episode cards loaded,
  a real MP3 started, and the Sveriges Radio media notification appeared with
  player metadata and controls. A physical Android device was not available for testing.

### Run and validate

Requirements: Flutter/Dart SDK and Android SDK installed. From the repository root:

```sh
flutter pub get
flutter run
```

Validation commands:

```sh
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d <device-id> # e.g. emulator-5554
flutter build apk --debug
```

Automated gates were last run on 2026-09-23 with Flutter 3.44.0 and all passed: formatting,
`flutter analyze`, 18 unit/widget tests, the integration smoke test on the Android emulator,
and the debug APK build. Playback in the emulator was additionally confirmed manually.
Test fixtures serve HTTP responses with an explicit `charset=utf-8` header so
non-ASCII episode titles decode identically on host and device.

### Add another curated show

Add a `PodcastProgram` item to `lib/src/podcast/data/podcast_catalog.dart`,
using the official API's verified program ID, name, canonical page URL, and
optional image URL. The initial app screen currently selects the first catalog entry.
Do not derive IDs from page slugs; confirm the program record and its episode
audio fields from the API before adding a program.

### Playback notes

Playback uses `just_audio` with `just_audio_background` for a single Android
media session and notification. Player operations sit behind a small `PodcastPlayer`
interface (`lib/src/podcast/audio/podcast_player.dart`), so widget and integration
tests run with an in-memory fake player and no audio hardware. Episode metadata
and streaming MP3s are served by Sveriges Radio. Network access is required;
download/offline playback and episode bookmarking are not implemented.
Background playback and Android notification controls should be confirmed on
a physical Android device before release.

## License

MPL-2.0
