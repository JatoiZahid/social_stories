# Social Stories (Flutter)

A children's social-story book built from the Figma reference. All 12 stories
(School, Toilet, Doctor, Brushing Teeth, Restaurant, Airport, Playground,
Sharing, Asking for Help, Personal Space, Saying No, Staying Safe) are **data**
in `assets/data/stories.json`, and they all play in **one** reusable
`StoryScreen`. There are no per-story screens.

## Windows: one-click scripts

Double-click these in the project folder. You need Flutter on PATH and the Android SDK, which Android Studio installs.

| Script | What it does |
| --- | --- |
| `setup.bat` | First-time setup: creates `android\`, adds the TTS permission, runs `flutter pub get`. The other scripts run it for you. |
| `build_apk.bat` | Builds a release APK to `dist\social_stories.apk` and opens the folder. `build_apk.bat debug` builds a debug APK; `build_apk.bat split` builds smaller per-CPU APKs. |
| `build_release_apk.bat` | Builds a **signed** release APK to `dist\social_stories-release.apk`, ready to share or upload. The first run asks for a password and creates your signing key (`android\upload-keystore.jks` + `android\key.properties`). `build_release_apk.bat aab` also builds a Google Play `.aab`. |
| `install_apk.bat` | Installs the APK on a USB-connected phone or emulator and opens the app. It builds the APK first if needed. |
| `run_emulator.bat` | Starts an Android emulator (or uses one that's already running), waits for it to boot, and runs the app with hot reload. `run_emulator.bat release` runs a release build; `run_emulator.bat Pixel_7_API_34` picks a specific emulator. If you have no emulator, it tries to create one. |
| `run_app.bat` | Runs the app with hot reload (`r` reloads, `q` quits). `run_app.bat release` runs a release build. |
| `run_server.bat` | Starts the **story server**: an admin web page to add and edit stories, plus the API the app downloads them from. `run_server.bat 9000` uses another port. |
| `build_admin_apk.bat` | Builds the **Stories Admin** app (review submissions, manage subscribers) to `dist\stories_admin.apk`. |

On the phone, turn on **Developer options → USB debugging** and accept the prompt when you plug it in.
`build_apk.bat` signs with Flutter's debug key, which is fine for quick testing. Use `build_release_apk.bat` for anything you share or publish. **Back up `upload-keystore.jks` and `key.properties`.** Without them you can't publish updates to the same app. Both are git-ignored.

## Story server: adding and updating stories for everyone

The app always opens with stories on screen. The first time, it shows the 12 stories bundled
with it. If a story server is set up, the app then fetches the latest list in the background
and saves it, so the new stories still show the next time the app opens offline. Pull down on
the library to check for new stories.

**1. Start the server.** Double-click `run_server.bat` (or `cd server && gradlew bootRun`).
The server is a **Spring Boot** app (Java 17+). The script uses `JAVA_HOME`, or the Java that
comes with Android Studio. The first start downloads Spring Boot, which takes a few minutes.
The window shows:

```
Admin page:   http://localhost:8080
Admin token:  k3m9...          ← the password for the admin page
App on the Android emulator uses:  http://10.0.2.2:8080
App on a phone on this Wi-Fi uses:  http://192.168.1.20:8080
```

The first start copies the 12 bundled stories into `server\data\stories.json`. Everything the
server saves (stories, uploaded pictures, the admin token) lives in `server\data\`. **Back up
that folder.**

**2. Edit stories.** Open the admin page in a browser and sign in with the token. From there you can:
- create a story, or edit the title and pages of an existing one
- add, duplicate, delete and reorder pages
- pick a bundled picture or **upload your own** (PNG, JPEG or WebP, max 5 MB), and frame it with the zoom and position sliders
- reorder or delete stories

Click **Save**, and the app gets the change the next time it loads stories.

**3. Point the app at the server.** Copy `story_server.txt.example` to `story_server.txt` and
put the address from step 1 on the first line. Then rebuild with `build_apk.bat`,
`build_release_apk.bat`, `run_app.bat` or `run_emulator.bat`; they all read this file.
- Without `story_server.txt`, debug runs use `http://10.0.2.2:8080` (the server on this PC, seen
  from the emulator), and release builds use only the bundled stories.
- A phone needs the server's Wi-Fi address (the `192.168...` line), and the PC's firewall must
  allow the port. Windows asks the first time the server starts. Allow it on **Private** networks.
- Manual builds: `flutter build apk --dart-define=STORY_SERVER_URL=http://192.168.1.20:8080`

| Setting (environment variable) | Default |
| --- | --- |
| `PORT` | `8080` |
| `ADMIN_TOKEN` | generated on first start, saved in `server\data\admin_token.txt` |
| `DATA_DIR` | `server\data` |
| `HOST` | `0.0.0.0` (reachable from other devices on the network) |
| `APP_DIR` | `..` (the Flutter app folder: its bundled stories and pictures) |

The same settings live in `server\src\main\resources\application.properties`. To run the server on
another machine, build one file with `cd server && gradlew bootJar` and run
`java -jar build\libs\social-stories-server-1.0.0.jar --stories.app-dir=<app folder>`.

**API.** Anyone can read; changes need `Authorization: Bearer <token>`.

| Method | Path | |
| --- | --- | --- |
| `GET` | `/api/stories` | all stories, in the same format as `assets/data/stories.json` |
| `GET` | `/api/stories/<id>` | one story |
| `POST` | `/api/stories` | create (body: story JSON) |
| `PUT` | `/api/stories/<id>` | replace a story |
| `DELETE` | `/api/stories/<id>` | delete a story |
| `PUT` | `/api/order` | reorder: `{"ids": [...]}`, every id once |
| `GET` | `/api/images` | pictures you can use (bundled + uploaded) |
| `POST` | `/api/images` | upload a picture (raw bytes) → `{"path": "uploads/..."}` |

Server tests: `cd server && gradlew test`.

**Notes**
- The app uses plain `http` to reach the server, which is fine on a home network. For a server
  on the internet, put it behind HTTPS (for example, a reverse proxy) and use an `https://` address.
- Uploaded pictures load over the network. The story text works offline, but an uploaded
  picture shows a placeholder until the app has been online with that story. Bundled
  pictures always work.
- Subscribers' changes go through review (below); only the web admin page and approved
  submissions change the published stories.

## Subscriptions, editing and review

Anyone can read stories. **Subscribers** can also add stories, change existing ones and write
quiz questions. Nothing they change reaches children until the admin approves it.

**For a subscriber (in the app)**
1. Tap the **gear** icon, then **Account & story editing**. Answer the grown-ups question
   (a quick sum, so children can't get in by accident).
2. **Create an account** or **sign in** (email + password).
3. Get a subscription:
   - **Google Play:** tap **Subscribe**. The server checks the purchase with Google before
     turning the subscription on.
   - **From the admin:** ask the admin to turn it on, then tap **Check again**.
4. Turn on **Edit stories**. The library now shows every story with an **Edit** badge and a
   **New story** tile. Tap a story to:
   - change the title and pages (pictures, framing, words; add, duplicate, delete, reorder)
   - tap **Quiz** to add or edit **multiple-choice questions** (2–4 answers each, tap ✓ next to
     the right one; up to 10 questions)
   - **Preview** it as a child would
5. Tap **Send for Review**. Changes are saved on the phone as a **draft** until then. Use
   **Discard my changes** to undo them.
6. Follow your changes under **Account › Sent for review**: waiting, approved or not approved
   (with the admin's note). **Take back** withdraws a change that hasn't been reviewed yet.

**For the admin (Stories Admin app)**
1. Build it with `build_admin_apk.bat` (→ `dist\stories_admin.apk`) and install it on your phone.
2. Connect with the server address and the **admin token** (both are shown in the server window).
3. **Review** tab: changes waiting for review, oldest first. Open one to see it:
   - **New story:** every page and its quiz
   - **Story changes:** now vs. after approval, changed pages only by default
   - **Quiz questions:** old vs. new questions, right answers ticked
   - A warning appears if the published story changed after the change was sent.

   **Approve** publishes it straight away, and the app picks it up the next time it loads
   stories. **Reject** leaves the story as it is. You can add a note either way, and the
   sender sees it.
4. **Subscribers** tab: everyone with an account. Tap a person to turn their subscription on
   (no end date, or until a chosen day) or off. Google Play subscriptions are shown, but
   Google manages them.

The web admin page (http://localhost:8080) still edits published stories directly, without review.

**Setting up Google Play subscriptions** (only needed for paid subscriptions; admin-granted ones work without it)
1. In Google Play Console, upload the app and create a **subscription** product with the id
   `social_stories_premium`. To use another id, set `SUBSCRIPTION_PRODUCT_ID` before running
   the build scripts.
2. Create a Google Cloud **service account**, invite it in Play Console (**Users and
   permissions**) with "View financial data", and download its **JSON key**.
3. Start the server with `GOOGLE_PLAY_SERVICE_ACCOUNT=<path to the JSON key>`. If your app id
   is not `com.socialstories.social_stories`, also set `GOOGLE_PLAY_PACKAGE`.
4. Test with a **license tester** account (Play Console › Settings › License testing). Google
   Play purchases only work in an app installed from Play (an internal testing track is enough).

The server re-checks a Google Play subscription with Google when its saved end date passes,
so renewals and cancellations are picked up automatically.

**Account and review API** (in addition to the story API above)

| Method | Path | Who | |
| --- | --- | --- | --- |
| `POST` | `/api/auth/register`, `/api/auth/login` | anyone | `{email, password, name?}` → `{token, user}` |
| `POST` | `/api/auth/logout` | user | ends this session |
| `GET` | `/api/me` | user | account + subscription |
| `POST` | `/api/me/google-play` | user | `{productId, purchaseToken}`: checked with Google |
| `GET`/`DELETE` | `/api/me/submissions[/<id>]` | user | your changes / take one back |
| `POST` | `/api/submissions` | subscriber | `{type: new_story \| edit_story \| edit_questions, storyId?, story}` |
| `GET` | `/api/admin/submissions?status=pending` | admin | review queue (`approved`, `rejected`, `all`) |
| `POST` | `/api/admin/submissions/<id>/approve` / `reject` | admin | `{note?}` |
| `GET` | `/api/admin/users`, `/api/admin/summary` | admin | accounts, counts |
| `PUT` | `/api/admin/users/<id>/subscription` | admin | `{active, until?: "2027-01-31"}` |

Users send `Authorization: Bearer <session token>`; the admin app and web page send the admin
token. Passwords are stored as salted PBKDF2 hashes, and session tokens as SHA-256 hashes. Accounts,
sessions and submissions are saved in `server\data\users.json` and `server\data\submissions.json`.

To add more pictures to the in-app picker, put the PNG in `assets/images/stories/` and add a line to `lib/data/scene_catalog.dart`.

## Run it manually

```bash
cd social_stories
flutter create . --project-name social_stories   # adds android/ ios/ web/ … (keeps lib/ and test/)
flutter pub get
flutter run
flutter test
```

**Android TTS (API 30+):** add this inside `<manifest>` in
`android/app/src/main/AndroidManifest.xml` so "Listen Again" can find the speech engine:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.TTS_SERVICE" />
  </intent>
</queries>
```

## Structure

```
lib/                            the app for children and subscribers
  main.dart / app.dart          entry point; injects settings, narrator, stories and account
  core/
    app_scope.dart              InheritedNotifier giving every widget the services
    app_config.dart             story server address (--dart-define=STORY_SERVER_URL)
    account/account_service.dart  sign-in, subscription, sending drafts for review
    account/billing.dart        Google Play subscription (in_app_purchase) · NoBilling (tests)
    settings/app_settings.dart  auto-read, large text, speech rate, edit mode (ChangeNotifier)
    narration/narrator.dart     Narrator interface · TtsNarrator · SilentNarrator (tests)
    theme/                      AppColors, AppDimens, AppTheme (Nunito)
  data/
    models/story.dart           Story, StoryPage, StoryQuestion (ids, copyWith, toJson)
    story_repository.dart       bundled stories.json + RemoteStoryRepository (story server)
    story_store.dart            published stories + this device's drafts, autosave
    account_api.dart            account, submission and review-status calls
    story_storage.dart          device storage (shared_preferences) / in-memory for tests
    scene_catalog.dart          the 12 scene illustrations editors can pick from
  features/
    library/library_screen.dart grid of StoryCoverCards
    story/story_screen.dart     the one story player
    story/quiz_screen.dart      multiple-choice quiz after the last page
    story/widgets/              StoryPageView (responsive), StoryControls
    account/account_screen.dart sign in, subscription, edit mode, "Sent for review"
    editor/story_editor_screen  title + page list, Quiz, Send for Review
    editor/page_editor_screen   picture, framing and text of one page
    editor/questions_editor_screen  quiz questions and their answers
    editor/widgets/             ScenePicker, FramingEditor, PageListTile, EditorTextField
  shared/widgets/               reusable UI kit (import widgets.dart)
    AppCard · ScreenHeader · RoundIconButton · InfoPill · PillButton
    SceneImage · NarrationCard · SpeakerBadge · ThumbnailStrip · PageDots
    SettingsSheet · CompletionDialog · StoryCoverCard · AddStoryCard
    ParentGate · ConfirmDialog
admin_app/                      Stories Admin (Flutter, Android)
  lib/api.dart                  admin API client and models
  lib/session.dart              server address + admin token, remembered on the device
  lib/screens/                  connect · home (tabs) · review · submission · users
  lib/widgets/                  page / question previews, before-after layout
server/                         story server (Spring Boot 4, Java)
  build.gradle.kts              dependencies; run with gradlew bootRun / test / bootJar
  src/main/java/com/socialstories/server/
    SocialStoriesServer         entry point
    StoryController             stories and pictures (/api/stories, /api/images)
    AccountController           sign-in, subscription, sending changes (/api/auth, /api/me)
    AdminController             review queue and subscribers (/api/admin)
    StoryStore                  published stories and validation (data/stories.json)
    SubmissionStore             the review queue (data/submissions.json)
    UserStore, Passwords        accounts and sessions (data/users.json)
    Subscriptions, GooglePlay   who is subscribed; checking Play purchases with Google
    AuthFilter, AccessCheck, Access   who is calling, and who may call what
    ImageLibrary, WebConfig, ApiErrors, StartupMessage, StoriesProperties
  src/main/resources/
    application.properties      settings (port, folders, token, Google Play)
    static/index.html           the web admin page
  src/test/java/...             ApiTest, ReviewFlowTest
```

## Adding or editing a bundled story

To change the stories that ship inside the app, which show before the server is
reached, add an entry to `assets/data/stories.json` and drop images in
`assets/images/stories/`. No Dart changes needed. `test/stories_data_test.dart`
checks that every image path exists.

```json
{
  "id": "haircut",
  "title": "Getting a Haircut",
  "cover": "assets/images/stories/haircut.png",
  "pages": [
    { "image": "assets/images/stories/haircut.png",
      "lead": "First, we sit in the big chair.",
      "body": "The hairdresser puts a cape on us." },
    { "image": "assets/images/stories/haircut.png",
      "focus": { "x": -0.4, "y": -0.2, "zoom": 1.4 },
      "lead": "We stay still while they cut.",
      "body": "It does not hurt." }
  ]
}
```

## Situation-specific artwork and action playback

The 12 original illustrations in `assets/images/stories/` remain unchanged and
serve as the character identity references. `docs/story_assets_baseline.json`
records their hashes and the original 75 narrated scenes. The scene-by-scene
requirements and generation specifications are in `docs/scene_asset_inventory.json`.

Each reviewed scene uses its own poster in `assets/images/story_scenes/` and a
fixed-grid action strip in `assets/animations/spritesheets/`. The source prompts,
review notes, native dimensions and hashes are recorded in
`docs/generated_scene_assets.json`. These are limited animations made from two
or three distinct illustrated action poses, rather than camera movement over a
static picture. Exports preserve native pixels using original PNG atlases and lossless PNG poster crops; they are not
native 4K art or full skeletal rigs. Frame dimensions vary by strip and are
recorded honestly for tablet review.

`StoryPage.animation` describes its atlas, grid, narration cue, frame count,
speed, meaningful still pose and whether the action loops. Optional `frameCues`
trigger specific multi-step poses at exact narration phrases; those phrase maps
are maintained in `docs/scene_frame_cues.json`. `AnimatedStoryScene`
draws exactly one atlas cell with `BoxFit.contain` geometry. A handover or other
one-shot sequence holds its final pose; repeated actions loop gently. Static
posters, library cards and thumbnails also preserve image proportions.

`ScenePlayback` shares a clock with narration. Native TTS word boundaries drive
narration progress when available; other engines use a speech-rate-based timing
estimate. Resume restarts at the last whole word, which can repeat a word on
some engines. Pause, replay, scene skips, settings and app backgrounding cancel
or freeze the corresponding speech and visual work. Navigation remains paced
by the child. Reduced motion, including the system setting, holds a meaningful
pose while retaining narration and all controls.

Changing a page's narration or image clears its previously reviewed animation.
New or edited stories need artwork review against their new text; the player
does not guess an animation from keywords. Optional quiz `choiceImages` stay
attached to matching answer text and survive storage, submission and admin
review. The original bundled stories contained no questions; remotely authored
questions and existing gentle retry behavior are preserved.

Older cached/server scenes receive new bundled art only when their title,
page order, text, image and framing exactly match the immutable original
signatures. This local upgrade preserves remote questions, server ordering,
removed stories and parent-authored edits. It never rewrites server data.

The maintenance scripts require Python 3.10+ and Pillow (`pip install Pillow`).
The checked build uses Flutter 3.47.5 / Dart 3.13.4. An iOS runner is included;
build and sign it with Xcode on a Mac for iPhone/iPad testing.

Useful maintenance commands:

```bash
python tools/audit_story_assets.py
python tools/generate_scene_manifest.py
python tools/integrate_scene_assets.py
python tools/integrate_scene_assets.py --check
flutter analyze
flutter test
cd admin_app && flutter test
cd ../server && gradlew test
```

The manifest exporter only processes already generated and visually reviewed
files. It does not call an image API. The integration checker verifies coverage,
original hashes, narrated text, asset hashes, atlas dimensions, distinct frames,
exact poster crops and references. These structural checks complement visual
review; they do not prove smooth motion or physical-device rendering.

`assets/data/stories.json` is now the authored source of truth.
`python tools/gen_stories.py assets/data/stories.json` validates/reformats it
without throwing away animations, quizzes or other authored metadata. A different
output path copies the current bundle unless `--source` is explicitly supplied.

Device-specific voice timing, performance and sharpness on Android/iOS tablets
still require physical-device review. See `docs/scene_asset_verification.json`
for completed structural checks and outstanding device checks.
