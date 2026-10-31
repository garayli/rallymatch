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
| Domain | **https://kortagel.com** (bought 2026-10-25) — custom domain on the default `rallymatch` site; `www.kortagel.com` redirects to the apex |
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

## Email (Resend + Supabase SMTP)

Login/signup codes are sent by Supabase Auth through Resend. Set up 2026-10-31.

| Item | Value |
|------|-------|
| Resend domain | `kortagel.com`, region **eu-west-1** (Ireland). Free plan: 1 domain, 100 emails/day, 3,000/month |
| DNS (Cloudflare) | Resend's records: TXT `resend._domainkey` (DKIM), CNAMEs `send` and `rsend` (sending, **DNS only** — a proxied CNAME breaks verification), TXT `_dmarc` = `v=DMARC1; p=none;`. Receiving is off (no MX) |
| Supabase → Authentication → Emails → SMTP | Custom SMTP **on**: host `smtp.resend.com`, port `465`, user `resend`, password = a Resend API key with Sending access to kortagel.com (stored only in Supabase), sender `noreply@kortagel.com`, name `Korta gel!` |
| Rate limit | Authentication → Rate Limits → "Rate limit for sending emails": keep it well above the default (e.g. ~100/hour) or a launch day hits it |
| Templates | **Confirm sign up** (new users) and **Magic Link** (existing users) must contain `{{ .Token }}`: the app's OTP screen (`auth_screen.dart`, `_codeLength = 8`) only takes a typed code. Email OTP Length in Supabase must stay **8** |

Test a new signup without a new inbox: a Gmail `+` alias (`name+test1@gmail.com`) is a different user in Supabase but lands in the same inbox. Delivery problems show in Resend → Emails and Supabase → Logs → Auth, not in the app (it only shows a generic error).

## Lobby invite links

`https://kortagel.com/l/<lobbyId>` (`lobbyLink()` in `lib/config/app_links.dart`) is shared from the lobby card (share button beside Join) and the organiser's manage sheet ("Davet linkini paylaş"). Route `AppRoutes.lobby` → `LobbyLinkScreen`.

- **Signed out** it is a public preview (RLS lets anon read public open/full lobbies) with "Kaydol ve katıl". The link is kept in `_pendingLobbyLink` (`app_router.dart`) through OTP and the signup wizard; the redirect sends the player back to it instead of /home.
- **Signed in** it shows the same Join / Manage / state button as the Match-tab card. Past, closed, private or unknown lobbies show "Bu lobi artık açık değil".
- **Web** uses path URLs (`usePathUrlStrategy()` in `main.dart`); Firebase Hosting rewrites every path to `index.html`.
- **Android App Links**: intent filter for `https://kortagel.com/l/` in `AndroidManifest.xml`, verified against `web/.well-known/assetlinks.json` (served by Hosting — `firebase.json` no longer ignores dot-folders). It must list the SHA-256 of every certificate that signs an installed build:

| Certificate | In assetlinks.json |
|-------------|--------------------|
| Debug (dev MacBook) | ✅ `71:9F:2E:…:40:B7` |
| Upload key | ⚠ not yet — `keytool -list -v -keystore android/upload-keystore.jks -alias upload` (the keystore wasn't on the dev Mac on 2026-10-31) |
| Play app signing | ⚠ add at first Play upload (Play Console → App integrity), together with the SHA-1 step above |

After changing `assetlinks.json`: `flutter build web --release && firebase deploy --only hosting`, check `https://kortagel.com/.well-known/assetlinks.json` returns the JSON, then on a device `adb shell pm verify-app-links --re-verify com.rallymatch.app` and `adb shell pm get-app-links com.rallymatch.app` → `kortagel.com: verified`. Until then Android opens the links in the browser (the web app), not the app.

WhatsApp link previews show the generic Kortagel card from `web/index.html`: the site is static, so per-lobby previews would need a server function.

## Push notifications (FCM, Android)

A push goes out for every new row in `notifications` (match requests, accept/decline, results — written by the app or n8n) and in `messages`.

```
app (push_service.dart) ── register_push_token RPC ──▶ push_tokens
notifications / messages INSERT ── Database Webhook ──▶ edge function `push` ── FCM HTTP v1 ──▶ device
```

- **App**: `PushService.register()` runs when MainShell has loaded (signed in, profile saved): asks for permission (Android 13+), saves the token through `register_push_token`. Sign-out calls `unregister()` first. A tapped push opens Messages or Bildirimler (`tab` in the FCM data → `shellTabForPush`). With the app open Android shows nothing; `onMessage` refreshes the data instead. Status-bar icon `res/drawable/ic_notification.xml`, colour `ic_launcher_background`.
- **DB**: `docs/migrations/2026-10-31_push_tokens.sql` — table with RLS and no policies; the app only goes through the two SECURITY DEFINER RPCs (a phone that switches accounts moves its token to the new player).
- **Edge function**: `supabase/functions/push/index.ts`. JWT verification **off**; it checks the `x-push-secret` header instead. Removes tokens FCM reports as gone. One notification per chat partner (Android `tag`).

### One-time setup
1. Supabase → SQL editor: run `docs/migrations/2026-10-31_push_tokens.sql` and `docs/migrations/2026-10-31_notify_requester.sql` (without the second, accept/decline notices to the requester are refused by RLS — no row, no push).
2. Firebase console → Project settings → Service accounts → **Generate new private key** (JSON). It's a password-level secret: never commit or paste it anywhere but step 4.
3. Supabase → Edge Functions → **Deploy a new function → Via editor**: name `push`, paste `supabase/functions/push/index.ts`, deploy. In the function's settings turn **Verify JWT off**.
4. Edge Functions → **Secrets**: `FIREBASE_SERVICE_ACCOUNT` = the whole JSON file content; `PUSH_WEBHOOK_SECRET` = a random string (`openssl rand -hex 24`).
5. Database → **Webhooks** → create two: table `notifications`, event **Insert**, type **Supabase Edge Functions** → `push`, POST; add HTTP header `x-push-secret` = the same random string. Same again for table `messages`.
6. Install a build with `firebase_messaging`, open it, allow notifications. `select * from push_tokens` should show the device.

Debug: Edge Functions → `push` → Logs/Invocations (each call returns `sent` / `removed` / `failed` or why it skipped); Database → Webhooks shows delivery status.

### Not covered yet
- The in-app notification preferences (`NotificationPreferencesScreen`) live only in memory, so the function can't honour them — every notification row is pushed.
- No web push and no iOS (no app); no banner while the app is in the foreground.

## Analytics (Firebase) — funnel events

All events go through `lib/services/analytics_service.dart` (fire-and-forget, errors swallowed; no-op when Firebase didn't start). `setUserId` is the Supabase user uuid, set on every auth state change in `app_router.dart` — never an email or phone. Screen views come from `FirebaseAnalyticsObserver` on the router.

| Event | Params | Logged in |
|-------|--------|-----------|
| `otp_requested` | `flow` = signup / login | `auth_screen.dart` after `signInWithOtp` succeeds |
| `otp_verified` | `flow` | `auth_screen.dart` after `verifyOTP` succeeds. The gap from `otp_requested` is the email-delivery drop-off |
| `sign_up` | `method` = email_otp | `signup_screen.dart` after the profile upsert |
| `login` | `method` = email_otp | `auth_screen.dart`, an account with a complete profile — from either button ("Get started" skips the wizard for returning players, so it never logs `sign_up`) |
| `match_requested` | `format`, `opponent_type` = registered / guest | `DataService.sendMatchRequest` |
| `match_request_responded` | `response` = accepted / declined | `DataService.respondToMatchRequest` |
| `lobby_created` | `sport`, `format`, `skill_level` | `open_lobby_screen.dart` |
| `lobby_joined` | `sport`, `source` = list / link | `DataService.joinLobby` |
| `result_submitted` | `opponent_type`, `outcome` = win / loss | `log_result_screen.dart` |
| `result_confirmed` / `result_disputed` | — | `DataService.confirmResult` / `disputeResult`. `result_confirmed` = a played match (North Star) |
| `message_sent` | — | `DataService.sendMessage` |
| `share` | `content_type` = result_card / lobby, `status` = success / dismissed / unavailable / copied | `result_card_screen.dart`, `lobby_actions.dart` |
| `push_permission` | `status` = authorized / denied / … | `push_service.dart`, answer to the Android 13+ prompt |
| `push_opened` | `tab` = alerts / messages | `push_service.dart`, a push was tapped |
| `lobby_link_opened` | `signed_in` = yes / no | `lobby_link_screen.dart`. Invite loop: `share` (lobby) → `lobby_link_opened` → `sign_up` → `lobby_joined` (source = link) |

Param values are canonical (Turkish data values, ADR-011), never localized labels. Add new events as a typed method on `AnalyticsService`, not as a raw `logEvent` call in a screen.

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
