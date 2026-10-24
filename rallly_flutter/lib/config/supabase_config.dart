import 'package:flutter/foundation.dart' show kIsWeb;

// ─── Supabase credentials ────────────────────────────────────────────────────
// Replace with your project's values from:
//   Supabase Dashboard → Project Settings → API
//
// Auth redirect: io.supabase.rallly://login-callback/ on mobile, the site's own
// origin on web — add both in Supabase Dashboard → Authentication → URL
// Configuration → Redirect URLs.

const supabaseUrl  = 'https://rxmoiwmitzbyqgichomm.supabase.co';
const supabaseAnon = 'sb_publishable_yO20WK1nEjVPa64d4_0olg_cXBAkl4f';

/// Where the link in the sign-in email returns to.
String get authRedirectUrl =>
    kIsWeb ? '${Uri.base.origin}/' : 'io.supabase.rallly://login-callback/';
