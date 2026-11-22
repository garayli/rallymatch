// ─── Microsoft Clarity ───────────────────────────────────────────────────────
// Project ID from clarity.microsoft.com → project → Settings. It is not a
// secret (it ships in the app), so it lives in source like the Supabase anon
// key. While it is empty Clarity is fully off: no SDK call, no consent prompt.
// Mobile only — the SDK has no web support (Flutter web renders to a canvas).

const clarityProjectId = 'zhrf8ym7ju';
