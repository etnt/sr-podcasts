# My favorite Sveriges Radio podcasts

The Sveriges Radio app makes it hard to find a specific podcast while you
drive. This project is a small Android app with a personal short list of
Sveriges Radio podcasts. You open the app and tap a show. The latest episodes
appear without a search.

## What the app does

The app is a Flutter app for Android. The home screen shows the shows that you
subscribe to. A subscription is a saved link to a show in the catalog of
Sveriges Radio. The app ships with the show Radiokorrespondenterna Kina in the
list.

You add more shows with the search screen. Episodes stream from the public API
of Sveriges Radio as MP3 files. Playback continues when the screen is off.
Android shows a media notification with player controls. The home screen shows
the app version next to the app name. A local build shows `dev`, and a tagged
release build shows the git tag.

## Screenshot

<a href="screenshots/screenshot.jpeg"><img src="screenshots/screenshot.jpeg" alt="Screenshot" width="19%"></a>

## Search and subscriptions

Tap the magnifier icon on the home screen to open the search screen. Type the
name of a show. The app filters the program catalog while you type. The filter
matches letters in the name or the description of a show. The results contain
podcast programs only.

The app downloads the full program catalog one time per session. The catalog
has 627 programs and the download is about 842 KB. 493 of the programs are
podcasts, as of 2026-09-23. The search API of Sveriges Radio returns HTTP 500,
and the program list endpoint ignores search parameters. The app therefore
filters the catalog on the phone.

The app stores subscriptions on the phone under the `shared_preferences` key
`subscriptions.v1`. The stored value is a JSON array with this shape:
`{id, name, programurl, programimage?, description?, haspod}`. The first app
start adds Radiokorrespondenterna Kina to the list. You can remove that show.
The app saves the change.

## API facts

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


## Add a show

You add shows in the app. Tap the magnifier icon, type the name of the show,
and tap the bookmark icon. The show then appears on the home screen.

The file `lib/src/podcast/data/podcast_catalog.dart` only defines the show for
the first app start. Make sure that the API returns the program record and the
audio field for a show before you rely on it. Do not guess the program ID from
the page address.

## Use the app in the car

The app appears in Android Auto on the car screen. The car shows its own
media screens, not the app's phone UI. You browse your saved shows, pick an
episode, and control playback with the car's buttons.

The app declares itself as a media app for Android Auto in
`android/app/src/main/res/xml/automotive_app_desc.xml`. The manifest points
at that file with the `com.google.android.gms.car.application` meta-data.
Without that declaration Android Auto does not list the app, even when the
media service is registered.

Things to check if the app does not show up in the car:

- Install a release APK, not the debug APK. Android Auto hides apps that are
  installed from outside Google Play unless you allow unknown sources. To
  test a debug build, enable developer settings in the Android Auto app on
  the phone (tap the Android Auto version ten times) and turn on
  `Unknown sources`. Then restart the car connection.
- Disconnect and reconnect the USB cable, or restart the phone, after you
  install a new build. The car reads the app list when the connection starts.

## Playback

The app plays audio with `just_audio` and `audio_service`. They provide one
media session, the media notification, and the Android Auto browse tree. The
player code sits behind the `PodcastPlayer` interface in
`lib/src/podcast/audio/podcast_player.dart`. Tests use an in-memory fake
player, so they run without audio hardware.

The app needs a network connection for episodes. It does not download episodes
for offline playback. It does not store the playback position between app
starts.

## License

The code uses MPL-2.0. See the `LICENSE` file for the full text. Sveriges
Radio owns the audio content.
