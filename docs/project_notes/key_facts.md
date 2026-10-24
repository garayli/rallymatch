# Key Facts

Project configuration, credentials, and constants.

## Supabase Configuration

| Key | Value |
|-----|-------|
| `supabaseUrl` | (fill in) |
| `supabaseAnon` | (fill in) |
| Redirect URL | `io.supabase.rallly://login-callback/` |

## Build Configuration

| Item | Value |
|------|-------|
| Flutter Project | `rallly_flutter/` |
| Min Android SDK | 21 |
| Target Android SDK | 34 |

## Firebase / Google Cloud

| Item | Value |
|------|-------|
| Project ID | `rallymatch` (owner: the Google account used for `firebase login` / `gcloud auth login`) |
| Android package | `com.rallymatch.app` |
| Config files | `rallly_flutter/lib/firebase_options.dart`, `rallly_flutter/android/app/google-services.json` — **gitignored** (GitHub secret scanning flagged the keys in commit `489ab8f`). Regenerate with `flutterfire configure`; placeholder template at `lib/firebase_options.dart.example` |
| Keys console | https://console.cloud.google.com/apis/credentials?project=rallymatch (sign in as the owner account) |

### Web hosting (PWA)

Hosted on **Cloudflare Pages** (free plan, no bandwidth cap). Firebase Hosting was dropped on 2026-10-24: a second site (`macagel.web.app`) needs the Blaze plan, and opening a Blaze billing account from Turkey asked for a 1,500 TL prepayment. The project stays on Spark; Firebase is still used for Analytics and Android.

| Item | Value |
|------|-------|
| Site | Pages project `macagel` → **https://macagel.pages.dev** (production, first deployed 2026-10-24). Each deploy also gets its own `<hash>.macagel.pages.dev` URL; `--branch <name>` other than `main` gives a preview at `<name>.macagel.pages.dev`. All of them use the same Supabase project (there is no separate dev database). |
| Config | None in the repo. Pages defaults already fit Flutter web: with no top-level `404.html` every unknown path serves `index.html` (GoRouter deep links work), and every file is sent with `Cache-Control: public, max-age=0, must-revalidate` (users get new builds without a hard refresh). Add `web/_headers` only to override that. |
| One-time setup (done) | Cloudflare account, `npx wrangler login`, Pages project `macagel` with production branch `main`. On a new machine only `npx wrangler login` is needed — plus `lib/firebase_options.dart` (gitignored; `flutterfire configure --project=rallymatch --platforms=android,web`, or copy the `.example` — web then just runs without Analytics), or `flutter build web` fails with `Error when reading 'lib/firebase_options.dart'`. |
| Deploy | `flutter build web --release && npx wrangler pages deploy build/web --project-name macagel --branch main` (from `rallly_flutter/`). Build locally: Cloudflare's builders don't have Flutter. `--branch main` makes it a production deploy whatever git branch is checked out; another branch name gives a preview URL. |
| Custom domain | None yet (deferred 2026-10-24; `macagel.com` is taken). When bought — preferably via Cloudflare Registrar, so DNS + SSL are automatic — add it under Workers & Pages → `macagel` → Custom domains, then add it to Supabase Redirect URLs and to the browser key's Websites restriction. |

Web setup state (2026-10-24, verified: Analytics Realtime showed the visit):
- **Supabase** → Authentication → URL Configuration → Redirect URLs has `https://macagel.pages.dev/**` (production) and `https://*.macagel.pages.dev/**` (per-deploy and preview URLs). Without them, email login on web fails.
- **Web Analytics** uses the browser key `Browser key (macagel.pages.dev)` (see below). It lives only in `web.apiKey` of the local, gitignored `lib/firebase_options.dart` — on a new machine `flutterfire configure` writes a different web key, so paste this one back from Cloud Console → Credentials → Show key before deploying. Check which key a build carries: `grep -o "AIza[0-9A-Za-z_-]\{35\}" build/web/main.dart.js` (only the web key is compiled in). With a missing or invalid key `main.dart` skips Firebase on web and Analytics no-ops; the app itself works.

### API key restrictions

Firebase client keys aren't real secrets, but they must be restricted so a key copied from git history is useless elsewhere. The project had three auto-created keys, all with a Firebase-only API allowlist. State as of 2026-09-21:

| Key | State |
|-----|-------|
| Android | active — restricted to package `com.rallymatch.app` + the debug and upload SHA-1s |
| iOS | **deleted 2026-09-21** (was unrestricted and exposed in commit `489ab8f`). No iOS Xcode project existed. |
| Browser (old) | **deleted 2026-09-21** (same reason). |
| `rally (web) (auto created by Firebase)` | **deleted 2026-10-24** — created by `flutterfire configure` with only an API allowlist (no website restriction) and never used by the deployed site. `flutterfire configure` will likely create another one: delete it again after putting the restricted key back into `web.apiKey`. |
| Browser `Browser key (macagel.pages.dev)` | active since 2026-10-24 — Websites restriction `https://macagel.pages.dev/*` + `https://*.macagel.pages.dev/*`, APIs Firebase Installations + Firebase Management. Not valid from `localhost`, so `flutter run -d chrome` runs without Analytics unless `http://localhost/*` is added. |

Deleted keys can be restored for ~30 days with `gcloud services api-keys undelete`. When iOS or web is set up, create a **new** key restricted from day one (iOS bundle ID / HTTP referrers), via `flutterfire configure` or the Console, and never reuse the deleted ones (they are in git history).

Key IDs and fingerprint values are deliberately not recorded here. Look up key IDs with `gcloud services api-keys list --project=rallymatch --format="table(displayName,uid)"`, and see what the Android key allows with `gcloud services api-keys describe <KEY_ID> --project=rallymatch --format="yaml(restrictions.androidKeyRestrictions)"`.

SHA-1 fingerprints the Android key allows, and where each comes from (`keytool` is in `C:\Program Files\Android\Android Studio\jbr\bin\` and is not on PATH):

| Certificate | How to get its SHA-1 |
|-------------|----------------------|
| Debug (this PC) | `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` |
| Upload | `keytool -list -v -keystore rallly_flutter/android/upload-keystore.jks -alias upload` (password is in `rallly_flutter/android/key.properties`). **Regenerated on the MacBook 2026-10-11** (the Windows keystore was lost); the new SHA-1 was added to the Android key the same day. Backed up in Google Drive. |
| **Play app signing** | **⚠ NOT ADDED YET — required at first Play upload (below)** |

A different PC has a different debug keystore, so its debug builds are blocked until that machine's SHA-1 is added too. The MacBook's (M1 Pro) debug SHA-1 was added on 2026-10-03 via Cloud Console. On macOS, `keytool` is at `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`.

#### ⚠ At first Play Store upload: add Play's app-signing SHA-1

Google Play re-signs every build it distributes (internal-testing track included) with its own certificate, so Play-installed builds carry a SHA-1 the Android key does not allow yet. Firebase calls from those builds fail with `403 Requests from this Android client application … are blocked`, while sideloaded builds signed with the debug/upload key keep working — so it stays invisible until testers install from Play.

1. Play Console → your app → Test and release → App integrity → Play app signing → copy the SHA-1 of the **App signing key certificate** (menu names shift between Console versions).
2. Add it to the Android key. Pass all three fingerprints (the update sets the whole list; lowercase hex, no colons):

   ```bash
   KEY_ID=$(gcloud services api-keys list --project=rallymatch --filter="displayName:Android" --format="value(uid)")
   gcloud services api-keys update "$KEY_ID" --project=rallymatch \
     --allowed-application=sha1_fingerprint=<DEBUG_SHA1>,package_name=com.rallymatch.app \
     --allowed-application=sha1_fingerprint=<UPLOAD_SHA1>,package_name=com.rallymatch.app \
     --allowed-application=sha1_fingerprint=<PLAY_SHA1>,package_name=com.rallymatch.app
   ```

   Or in the Console: Credentials → Android key → Application restrictions → Add an item.
3. Install from the Play track and confirm Firebase events arrive, then update the table above.

## External Resources

| Resource | URL |
|----------|-----|
| InstrumentSerif Font | Google Fonts |
| Plus Jakarta Sans | Google Fonts |

## Figma MCP

| Key | Value |
|-----|-------|
| Account | leyla.garayli@gmail.com |
| Team | Lei La's team (Starter plan) |
| Seat | View (read-only) |
| Token scope | Read only — write-back unavailable on free plan |
| Token storage | Environment variable `$env:FIGMA_TOKEN` in local scripts only — never commit |

## Connected Devices

| Device | ID |
|--------|----|
| SM A566B (Android 16) | `R5CY41DEJZZ` |

---

## Supabase Table Schemas

### `matches`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK, default `gen_random_uuid()` |
| `player1_id` | uuid | Requester — FK → `profiles.id` (NOT auth.users) |
| `player2_id` | uuid | Opponent — nullable (mock IDs not UUIDs, see ADR-005) |
| `date_time` | timestamptz | NOT NULL |
| `court` | text | NOT NULL |
| `status` | enum | `'pending'` \| `'confirmed'` \| `'completed'` \| `'cancelled'` |
| `format` | enum | `'singles'` \| `'doubles'` |
| `winner_id` | uuid | nullable FK → `profiles.id` — set on match completion |
| `sets` | jsonb | nullable — set scores |
| `rating_delta` | real | nullable |
| `opponent_name` | text | nullable — unregistered opponent display name |
| `opponent_phone` | text | nullable — unregistered opponent phone (min 10 digits) |
| `lobby_id` | uuid | nullable FK → `lobbies.id` — set when the row is a lobby join request (lobby v2) |
| `created_at` | timestamptz | auto |
| `updated_at` | timestamptz | auto |

### `lobbies`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK, default `gen_random_uuid()` |
| `creator_id` | uuid | FK → `auth.users`, NOT NULL |
| `sport` | text | `'Tenis'` \| `'Padel'` \| `'Badminton'` \| `'Squash'` |
| `skill_level` | text | `'Her seviye'` \| `'Başlangıç'` \| `'Orta Seviye'` \| `'İleri Seviye'` |
| `date_time` | timestamptz | NOT NULL |
| `court` | text | NOT NULL |
| `notes` | text | nullable |
| `is_public` | bool | NOT NULL, default true |
| `status` | text | `'open'` \| `'full'` \| `'closed'` \| `'cancelled'`, default `'open'` (closed/full via lobby v2 migration) |
| `format` | text | `'singles'` \| `'doubles'`, default singles (lobby v2) |
| `pending_count`, `accepted_count` | int | trigger-maintained, never written by the app (lobby v2) |
| `created_at` | timestamptz | auto |
RLS: anyone can SELECT where `is_public=true AND status IN ('open','full')` (creator sees all own); only `creator_id=auth.uid()` can INSERT/UPDATE.

### `messages`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `sender_id` | uuid | FK → `profiles.id` |
| `receiver_id` | uuid | Nullable FK → `profiles.id` (see ADR-004) |
| `text` | text | |
| `timestamp` | timestamptz | |
| `is_read` | bool | default false |

---

---

## Key Dependencies (non-obvious)

| Package | Version | Purpose |
|---------|---------|---------|
| `shared_preferences` | ^2.2.0 | Persists per-tab onboarding seen-state (`onboarding_seen` key, `List<String>` of tab indices) |
| `flutter_animate` | ^4.5.0 | Fade/slide animations on cards and overlays |
| `flutter_map` | ^6.0.1 | Map screen (OpenStreetMap tiles) |

---

## Notes

- Update this file when configuration changes
- Never commit actual credentials to version control

## Local Android build (macOS)
- Android Studio's bundled JDK is **25**, which Gradle 8.14 here can't use (build fails with just `25.0.3`). Use JDK 21: `flutter config --jdk-dir <jdk21 home>` (installed at `~/development/jdk21` on the dev Mac) and `flutter config --android-sdk ~/Library/Android/sdk`, then `flutter doctor --android-licenses`.
- Flutter lives at `~/development/flutter/bin` and isn't on PATH by default.
- A build also needs the gitignored `android/app/google-services.json` and a real `lib/firebase_options.dart` (the `.example` placeholders `YOUR_API_KEY` fail at startup).
- `flutter run -d web-server --web-port 8099` serves the web build; a stale server on 8080 once showed old code — check `lsof -iTCP:<port>` when "nothing changed".
