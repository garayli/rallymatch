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

| Item | Value |
|------|-------|
| Domain | **https://kortagel.com** (bought 2026-10-25, **live** since 2026-10-29) — custom domain on the default `rallymatch` site; `www.kortagel.com` redirects to the apex |
| Site | `rallymatch` → https://rallymatch.web.app (Spark/free plan, the project's default site). Keeps working after the domain is connected, but share/install from kortagel.com. A separate `macagel` site was planned but never created |
| Config | `rallly_flutter/firebase.json` → `hosting` (serves `build/web`, SPA rewrite to `index.html` for GoRouter, `no-cache` on `index.html` / service worker / bootstrap / manifest) + `rallly_flutter/.firebaserc` |
| Deploy | `flutter build web --release && firebase deploy --only hosting` (from `rallly_flutter/`) |

Before the web build works end to end: create a new **browser** API key restricted to `https://kortagel.com/*`, `https://www.kortagel.com/*` and `https://rallymatch.web.app/*` (see below), and in Supabase → Authentication → URL Configuration set **Site URL** to `https://kortagel.com` and add `https://kortagel.com/**` and `https://rallymatch.web.app/**` to Redirect URLs (keep `io.supabase.rallly://login-callback/`). `authRedirectUrl` uses the page's own origin, so no code change is needed per domain.

#### Connecting kortagel.com (one-time)

Custom domains and their SSL certificates are free on the Spark plan — no Blaze upgrade needed. Use **Hosting** (Build → Hosting), not **App Hosting**: App Hosting is for server-rendered apps and asks for Blaze; this static Flutter build doesn't need it.

1. Firebase Console → Hosting → site `rallymatch` → **Add custom domain** → `kortagel.com`. Firebase shows a TXT record (ownership) and A record(s) — add them at the registrar's DNS panel, deleting any existing A/AAAA/parking records for `@`.
2. Add custom domain again → `www.kortagel.com` → choose **Redirect to kortagel.com**; add the CNAME/A records it shows.
3. Wait for status "Connected" (DNS can take up to 24h; the SSL certificate is issued automatically afterwards). If the domain then shows Firebase's **"Site Not Found"** page while another domain on the same site works, run `firebase deploy --only hosting` again — the new domain only picks up content on the next release (hit on kortagel.com, 2026-10-26). The Hosting dashboard card lists only the first few domains; use "View all N domains" to find the rest.

Cloudflare DNS (registrar for kortagel.com): A `@` → `199.36.158.100`, TXT `@` → `hosting-site=rallymatch`, CNAME `www` → `rallymatch.web.app`, all **DNS only** (grey cloud) — the orange proxy breaks Firebase verification and certificate minting. Ignore Cloudflare's "Proxying is required" banner.
4. Do the Supabase URL + browser-key steps above, then `flutter build web --release && firebase deploy --only hosting`.

`web/index.html` hardcodes `https://kortagel.com/` in `canonical`, `og:url` and `og:image` (link previews need an absolute image URL); the result-share text (`shareText` in the ARB files) ends with `kortagel.com`.

### API key restrictions

Firebase client keys aren't real secrets, but they must be restricted so a key copied from git history is useless elsewhere. The project had three auto-created keys, all with a Firebase-only API allowlist. State as of 2026-09-21:

| Key | State |
|-----|-------|
| Android | active — restricted to package `com.rallymatch.app` + the debug and upload SHA-1s |
| iOS | **deleted 2026-09-21** (was unrestricted and exposed in commit `489ab8f`). No iOS Xcode project existed. |
| Browser | **deleted 2026-09-21** (same reason). No web domain existed; `flutter run -d chrome` has no working Firebase key until a new one is created. |

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
