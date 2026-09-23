---
goal: Add multi-show support with SR podcast search, local subscriptions, version badge, and tag-driven GitHub releases
version: 1.0
date_created: 2026-09-23
last_updated: 2026-09-23
owner: Repository maintainers
status: 'Completed'
tags: [feature, flutter, android, podcast, search, subscriptions]
---

# Introduction

![Status: Completed](https://img.shields.io/badge/status-Completed-brightgreen)

This plan extends the existing Android-first Flutter player (Radiokorrespondenterna Kina) so the user can search Sveriges Radio's podcast catalog, "subscribe" to shows, and browse episodes for every subscribed show. It also adds the app-version badge beside the app name and a tag-triggered GitHub Actions release workflow per the updated flutter-app-development skill guidance. Sveriges Radio's dedicated search endpoints return HTTP 500 and the API ignores query/filter parameters, so search is implemented as a client-side filter over the full program list fetched once per session.

## 1. Requirements & Constraints

- **REQ-001**: The home screen lists all subscribed shows with artwork and name; tapping a show opens its episode screen. The first-run default subscription is Radiokorrespondenterna Kina (program 5386).
- **REQ-002**: A search screen lets the user find SR podcasts by name/description and subscribe/unsubscribe from the results. Results include only programs with `haspod=true` (493 of 627 programs as of 2026-09-23).
- **REQ-003**: Subscriptions persist locally across app restarts (no account/server). Unsubscribing removes the show from the home list; it can be re-added via search.
- **REQ-004**: The app version appears as small print beside the app name in the home AppBar, injected at build time via `--dart-define=APP_VERSION` with a `dev` fallback for local builds.
- **REQ-005**: Pushing a `v*` git tag triggers a GitHub Actions workflow that runs analyze/tests, builds release APKs (split-per-ABI + universal) with `APP_VERSION=${{ github.ref_name }}`, and publishes them to a GitHub Release.
- **SEC-001**: No signing material, secrets, or keystores may be committed. The workflow must support adding signing later through repository secrets only.
- **CON-001**: Sveriges Radio's `autocomplete`, `searchresults`, and `search` API endpoints return HTTP 500, and `programs/index` ignores `query`, `programslug`, and `haspod` parameters (verified 2026-09-23). Search must therefore filter client-side over one full-list request (~842 KB, 627 programs).
- **CON-002**: Keep the existing Riverpod + plain-Navigator architecture; no router migration is warranted for a two-level navigation flow.
- **GUD-001**: Keep parsing, persistence, and playback outside widgets so behavior is testable offline; new network and persistence code must be unit-testable with fakes.
- **GUD-002**: One malformed program entry must not break the entire search corpus; skip and continue parsing remaining entries.
- **PAT-001**: Follow the existing feature-first layout under `lib/src/podcast/` (data/domain/audio/presentation) and the established Material 3 theming.
- **PAT-002**: Follow the skill's version-badge pattern: a single `appVersion` constant in `lib/src/config/app_version.dart` shown via `Text.rich` small print; release artifacts flow the git tag in via `--dart-define`.

## 2. Implementation Steps

### Implementation Phase 1 — Search corpus and subscription persistence

- **GOAL-001**: Provide a fetchable, parseable program corpus and durable local subscriptions as testable foundations.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Add `shared_preferences` to `pubspec.yaml`, create `lib/src/config/app_version.dart` with the `appVersion` dart-define constant, and bump the app version. | ✅ | 2026-09-23 |
| TASK-002 | Extend `PodcastProgram` with optional `description` and `haspod`, plus `fromJson`/`toJson` for persistence and API parsing. | ✅ | 2026-09-23 |
| TASK-003 | Add `SrApiClient.fetchAllPrograms()` fetching `programs/index?pagination=false`, parsing id/name/slug/url/image/description/haspod, skipping malformed entries (GUD-002), and reusing existing HTTP error handling. Add a representative fixture. | ✅ | 2026-09-23 |
| TASK-004 | Add a SharedPreferences-backed `SubscriptionsNotifier` (AsyncNotifier) storing JSON under a versioned key, seeding the default show on first run, and exposing subscribe/unsubscribe operations. | ✅ | 2026-09-23 |

### Implementation Phase 2 — Multi-show UI

- **GOAL-002**: Replace the single-show home with a subscriptions home and an SR podcast search screen.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-005 | Create `SubscriptionsScreen` as the new home: version badge in the AppBar, subscribed-show list with artwork, unsubscribe action, loading/error/empty states, and navigation into a show's episodes. | ✅ | 2026-09-23 |
| TASK-006 | Create `SearchProgramScreen`: search field filtering the in-memory corpus case-insensitively across name/description, podcast-only results, subscribe/unsubscribe toggles, loading/error/empty/no-match states, and tap-through to a show's episodes. | ✅ | 2026-09-23 |
| TASK-007 | Rewire `lib/main.dart` to initialize SharedPreferences and open `SubscriptionsScreen`; give `PodcastScreen` the program name as AppBar title with back navigation. | ✅ | 2026-09-23 |

### Implementation Phase 3 — Release tooling and docs

- **GOAL-003**: Ship tag-driven releases and document the workflow.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-008 | Add `.github/workflows/release.yml` per the skill pattern: `v*` tag + manual triggers, analyze and tests, split-per-ABI and universal release APKs with `--dart-define=APP_VERSION=${{ github.ref_name }}`, published via `softprops/action-gh-release@v2`. Omit keystore steps until signing secrets exist (SEC-001). | ✅ | 2026-09-23 |
| TASK-009 | Update `README.md`: search/subscribe usage, persistence schema, search-corpus caveat (single ~842 KB request), version badge injection, and how to cut a `v*` release; note signing as a follow-up. | ✅ | 2026-09-23 |

### Implementation Phase 4 — Tests and validation

- **GOAL-004**: Cover the new behavior offline and re-validate the full pipeline.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-010 | Unit tests for `fetchAllPrograms` (fixture parsing incl. Swedish text, malformed-entry skipping, HTTP and JSON errors) and for subscription persistence (first-run seeding, subscribe/unsubscribe round-trip via mocked SharedPreferences). | ✅ | 2026-09-23 |
| TASK-011 | Widget tests for the subscriptions home (version badge, seeded list, empty state, unsubscribe) and the search screen (loading, error+retry, filtered results, subscribe toggle, no-match state). | ✅ | 2026-09-23 |
| TASK-012 | Update the integration smoke test to launch the real app: seeded home → open show → episodes render → play via fake player → pause. | ✅ | 2026-09-23 |
| TASK-013 | Run all gates: format, analyze, tests, integration test on the emulator, and debug APK build; update plan/README statuses to reflect results. | ✅ | 2026-09-23 |

## 3. Alternatives

- **ALT-001**: Use SR's `autocomplete`/`searchresults` endpoints. Rejected: both return HTTP 500 (verified 2026-09-23).
- **ALT-002**: Server-side filtering via `programs/index?query=`. Rejected: the parameter is ignored; the API returns all 627 programs regardless.
- **ALT-003**: Persist the program corpus on disk for offline search. Deferred: an in-memory session cache is sufficient for the MVP; disk caching can be added later if cold-start cost matters.
- **ALT-004**: Migrate to `go_router`. Deferred: the app has a two-level flow with no deep links; plain Navigator is the smaller dependency (CON-002).
- **ALT-005**: Signed release workflow now. Deferred: no keystore exists; the skill reference explicitly supports unsigned artifacts until signing secrets are provisioned.

## 4. Dependencies

- **DEP-001**: `shared_preferences` for local subscription persistence.
- **DEP-002**: Existing verified SR API contract: `programs/index?pagination=false` for the corpus and `episodes/index?programid=` for episodes.
- **DEP-003**: GitHub Actions (ubuntu-latest, Flutter stable, JDK 17) and `softprops/action-gh-release@v2` for tagged releases.
- **DEP-004**: Attached Android emulator for the integration smoke test (emulator-5554 available as of 2026-09-23).

## 5. Files

- **FILE-001**: `lib/src/config/app_version.dart` — dart-define version constant.
- **FILE-002**: `lib/src/podcast/domain/podcast_program.dart` — adds description/haspod and JSON codecs.
- **FILE-003**: `lib/src/podcast/data/sr_api_client.dart` — adds `fetchAllPrograms()`.
- **FILE-004**: `lib/src/podcast/data/subscriptions.dart` — persistent subscription store.
- **FILE-005**: `lib/src/podcast/data/podcast_providers.dart` — adds the all-programs corpus provider.
- **FILE-006**: `lib/src/podcast/presentation/subscriptions_screen.dart` — new home screen.
- **FILE-007**: `lib/src/podcast/presentation/search_program_screen.dart` — search and subscribe screen.
- **FILE-008**: `lib/src/podcast/presentation/podcast_screen.dart` — per-show title and back navigation.
- **FILE-009**: `lib/main.dart` — SharedPreferences init and new home.
- **FILE-010**: `.github/workflows/release.yml` — tag-driven release workflow.
- **FILE-011**: `pubspec.yaml` / `pubspec.lock` — new dependency and version bump.
- **FILE-012**: `test/fixtures/sr_programs.json` — representative program-corpus fixture.
- **FILE-013**: `test/src/podcast/data/sr_api_client_test.dart` — corpus fetch tests.
- **FILE-014**: `test/src/podcast/data/subscriptions_test.dart` — persistence tests.
- **FILE-015**: `test/src/podcast/presentation/subscriptions_screen_test.dart` — home-screen tests.
- **FILE-016**: `test/src/podcast/presentation/search_program_screen_test.dart` — search-screen tests.
- **FILE-017**: `integration_test/podcast_smoke_test.dart` — full app-flow smoke test.
- **FILE-018**: `README.md` — usage, release, and search-corpus documentation.
- **FILE-019**: `plan/feature-multi-show-subscriptions-1.md` — this plan.

## 6. Testing

- **TEST-001**: `fetchAllPrograms` parses the fixture (incl. non-ASCII text), skips malformed entries, and surfaces HTTP/JSON errors — all with fake HTTP.
- **TEST-002**: Subscriptions seed the default show on first run and survive subscribe/unsubscribe round-trips through mocked SharedPreferences.
- **TEST-003**: Subscriptions home shows the version badge, the seeded show, an empty state when unsubscribed, and removes a show on unsubscribe.
- **TEST-004**: Search screen shows loading/error+retry/filtered-results/no-match states and toggles subscriptions from results.
- **TEST-005**: Integration smoke test launches the real app on the emulator: seeded home → open show → episodes → fake playback → pause, fully offline.
- **TEST-006**: `dart format`, `flutter analyze`, `flutter test`, integration test, and `flutter build apk --debug` all pass.

## 7. Risks & Assumptions

- **RISK-001**: The ~842 KB corpus request on first search per session could feel slow on poor connections; mitigated by a session cache and stated in the UI's loading state.
- **RISK-002**: `just_audio_background` is a beta package; tagged releases should be smoke-tested after each bump.
- **RISK-003**: Client-side search may miss SR metadata nuances (e.g., renamed shows) that a server-side index would catch; revisit if SR fixes its search endpoints.
- **ASSUMPTION-001**: Local-only subscriptions (no sync) are acceptable for this personal app.
- **ASSUMPTION-002**: Releases are unsigned/debug-signed until the user provisions a keystore and GitHub secrets.

## 8. Related Specifications / Further Reading

- Prior plan: `plan/feature-sr-podcast-player-1.md` (completed)
- SR program corpus: <https://api.sr.se/api/v2/programs/index?pagination=false&format=json>
- SR episode endpoint: <https://api.sr.se/api/v2/episodes/index?programid=5386&format=json>
- Skill reference: flutter-app-development `references/platform-release.md` (version badge and release workflow pattern)
