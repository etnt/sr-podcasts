# Development

This document is for anyone who builds, tests, or releases the app. For what
the app does and how to use it, see [README.md](README.md).

## Run the app

You need the Flutter SDK and the Android SDK on your computer. Open a terminal
in the repository root.

```sh
flutter pub get
flutter run
```

## Test the app

Run these commands from the repository root.

```sh
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d <device-id> # e.g. emulator-5554
flutter build apk --debug
```

The integration test needs a connected device or emulator. Replace
`<device-id>` with an ID from `flutter devices`.

The last validation run used Flutter 3.44.0 on 2026-09-23. All commands
passed. The suite contains 34 unit tests and widget tests. A developer also
confirmed playback in the emulator by hand. The test fixtures send HTTP
responses with an explicit `charset=utf-8` header, so non-ASCII titles decode
the same way on the computer and on the device.

A developer tested the full app by hand in the Android 14 Pixel emulator on
2026-09-23. The app started, episodes loaded, playback ran, and the media
notification appeared. A test on a physical Android device is still open.

## Cut a release

The release workflow lives in `.github/workflows/release.yml`. It starts when
you push a git tag that starts with `v`.

1. Run `git tag v1.0.0`.
2. Run `git push origin v1.0.0`.
3. Wait for the workflow. It runs the checks and builds split-per-ABI APKs and
   one universal APK.
4. The build sets the app version from the tag with
   `--dart-define=APP_VERSION=${{ github.ref_name }}`.
5. The workflow attaches the APK files to a GitHub Release.

Release APKs are signed with a persistent keystore so that updates can be
installed over previous versions without conflicts. The signing key is stored as
GitHub Actions secrets and decoded at build time.

**Repository secrets required** (Settings → Secrets and variables → Actions):

| Secret              | Value                                            |
|---------------------|--------------------------------------------------|
| `KEYSTORE_BASE64`   | The release keystore, base64-encoded: `base64 -i android/release-keystore.jks` |
| `KEYSTORE_PASSWORD` | Password for both the keystore and the key alias |

The Gradle build reads `android/key.properties` when present; the workflow
creates that file from secrets before building. Locally, if `key.properties`
does not exist, the build falls back to the debug signing key.

**Generating a new keystore** (only needed if the original is lost):

```bash
keytool -genkey -v \
  -keystore android/release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release
```

## Update check

On launch, the home screen checks GitHub Releases
(`etnt/sr-podcasts`) for a newer version using the `auto_upgrade` package
(a git dependency in `pubspec.yaml`). If one exists, a dialog offers
**Update now**, which opens the release page in the browser, or **Later**.
Nothing opens without the user's tap.

- The check runs at most once per 24 hours across restarts
  (`SharedPrefsUpdateCheckStore`, wired in `main.dart`).
- Errors and offline launches are silent. Dev builds (no `APP_VERSION`)
  skip the check entirely, so `flutter run` never hits the network.
- The `https` query in `AndroidManifest.xml` lets `url_launcher` open the
  browser on Android 11+.
- Widget tests use a fake `ReleaseChecker` via `releaseCheckerProvider`.

## Sveriges Radio API facts

The app talks to the public API of Sveriges Radio at `api.sr.se`. A developer
checked the facts in this list against the live API on 2026-09-23.

- Program: Radiokorrespondenterna Kina, program ID `5386`
- Program record: `https://api.sr.se/api/v2/programs/5386?format=json`
- Episode endpoint:
  `https://api.sr.se/api/v2/episodes/index?programid=5386&format=json`
- Audio field for an episode: `episodes[].listenpodfile.url`
- The episode endpoint is paginated. The app requests pages of 100 episodes
  and follows `pagination.nextpage` links. It accepts HTTPS links on
  `api.sr.se` only.
- One MP3 URL answered with `200 audio/mpeg` during the check.
- The Sveriges Radio website blocked automated reads during development. The
  app uses the official API and the show page link. It does not read the
  website HTML.

## Search and the program catalog

The catalog has 627 programs and the download is about 842 KB. 493 of the
programs are podcasts, as of 2026-09-23. The search API of Sveriges Radio
returns HTTP 500, and the program list endpoint ignores search parameters. The
app therefore downloads the full catalog once per session and filters it on the
phone. The filter matches letters in the name or the description of a show,
and the results contain podcast programs only.

## Storage of subscriptions

The app stores subscriptions on the phone under the `shared_preferences` key
`subscriptions.v1`. The stored value is a JSON array with this shape:
`{id, name, programurl, programimage?, description?, haspod}`.

## The built-in show

The file `lib/src/podcast/data/podcast_catalog.dart` only defines the show for
the first app start. Make sure that the API returns the program record and the
audio field for a show before you rely on it. Do not guess the program ID from
the page address.

## Android Auto declaration

The app declares itself as a media app for Android Auto in
`android/app/src/main/res/xml/automotive_app_desc.xml`. The manifest points
at that file with the `com.google.android.gms.car.application` meta-data.
Without that declaration Android Auto does not list the app, even when the
media service is registered.

To keep car browsing responsive, Android Auto shows the latest API page, up
to 100 episodes per show. The phone UI can still load the complete episode
history.

The media session and the in-app player bar expose rewind and fast-forward
buttons that jump 15 seconds within the current episode. Previous and next
still change the episode: the in-app player bar shows prev/next episode
buttons. UNVERIFIED: the car is expected to reach previous and next through
the system actions and the queue (see the trade-off and verification notes
below).

The session publishes at most three controls (rewind, play/pause,
fast-forward). One shared controls list serves both the car player and the
phone notification because audio_service exposes a single media session;
separate control sets per client are not possible with this package. The
car fix is UNVERIFIED: a manual test observed the Android Auto player
appearing to break on a wider control set, and the car reaches previous and next
only through the system actions and the queue on the unconfirmed
assumption that system actions are capabilities rather than rendered
buttons. The trade-off is that the phone notification and lock screen
also show only the three car-safe controls and lose the episode
prev/next buttons; on the phone, episode changes happen in the in-app
player bar instead (the compact action indices affect only the phone
notification's compact view, and Android Auto appears to ignore them and
lay out its own slots — observed, not verified).

KNOWN TRADE-OFF, NEEDS PRODUCT SIGN-OFF: the phone notification and lock
screen show only rewind, play/pause, and fast-forward and no longer offer
episode prev/next. Prev/next remain only in the in-app player bar. Product
must sign off on losing prev/next on the notification and lock screen
before the three-control set is treated as final.

Open verification item: verify the whole car fix on a device or desktop
head unit (DHU) with `adb logcat` before treating the car breakage as
fixed: (a) confirm that a wider control set actually broke the car
player, (b) confirm that the three-control set keeps the car player
working, and (c) confirm that system actions do not render as episode
step buttons in the car player.

## Playback architecture

The app plays audio with `just_audio` and `audio_service`. They provide one
media session, the media notification, and the Android Auto browse tree. The
player code sits behind the `PodcastPlayer` interface in
`lib/src/podcast/audio/podcast_player.dart`. Tests use an in-memory fake
player, so they run without audio hardware.
