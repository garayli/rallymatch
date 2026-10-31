// ─── Public links ────────────────────────────────────────────────────────────
// Links shared outside the app point at the website. On Android, `/l/…` opens
// the app instead (App Links: the intent filter in AndroidManifest.xml +
// `web/.well-known/assetlinks.json`); everywhere else the web app handles it.

const appOrigin = 'https://kortagel.com';

/// Invite link to one lobby — routed by `AppRoutes.lobby` in the app.
String lobbyLink(String lobbyId) => '$appOrigin/l/$lobbyId';
