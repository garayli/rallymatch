// Sends an FCM push for every new `notifications` or `messages` row.
//
// Called by two Database Webhooks (INSERT on public.notifications and on
// public.messages) with the header `x-push-secret`. Deploy with JWT
// verification OFF — the shared secret is the check. Setup steps:
// docs/project_notes/key_facts.md → Push notifications.
//
// Secrets (Edge Functions → Secrets):
//   FIREBASE_SERVICE_ACCOUNT  the whole JSON key of a Firebase service account
//   PUSH_WEBHOOK_SECRET       random string, also set as the webhooks' header
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
//
// No imports on purpose: nothing to fetch or resolve when the function boots.

type Row = Record<string, unknown>;

interface WebhookPayload {
  type: string; // INSERT | UPDATE | DELETE
  table: string;
  record: Row | null;
}

interface Push {
  userId: string;
  title: string;
  body: string;
  // Read by the app (push_service.dart): `tab` = alerts | messages.
  data: Record<string, string>;
  // Same tag replaces the previous notification (one per chat partner).
  tag?: string;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-push-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }

  try {
    const payload = (await req.json()) as WebhookPayload;
    if (payload.type !== "INSERT" || !payload.record) {
      return json({ skipped: "not an insert" });
    }

    const push = await buildPush(payload.table, payload.record);
    if (!push) return json({ skipped: "nothing to send" });

    const tokens = (await db(
      `push_tokens?select=token&user_id=eq.${encodeURIComponent(push.userId)}`,
    )) as { token: string }[];
    if (!tokens.length) return json({ skipped: "no devices" });

    const results = await Promise.all(tokens.map((t) => send(t.token, push)));
    return json({
      sent: results.filter((r) => r === "sent").length,
      removed: results.filter((r) => r === "removed").length,
      failed: results.filter((r) => r === "failed").length,
    });
  } catch (e) {
    console.error("push failed:", e);
    return json({ error: String(e) }, 500);
  }
});

// ── Database (PostgREST with the service role key, bypasses RLS) ────────────

async function db(path: string, init: RequestInit = {}): Promise<unknown> {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: key, "Content-Type": "application/json" },
  });
  if (!res.ok) {
    throw new Error(`db ${path.split("?")[0]} ${res.status}: ${await res.text()}`);
  }
  return res.status === 204 ? null : await res.json();
}

// ── What to send ─────────────────────────────────────────────────────────────

async function buildPush(table: string, r: Row): Promise<Push | null> {
  if (table === "notifications") {
    // Title/body are written by the app or n8n in Turkish (ADR-011).
    return {
      userId: String(r.user_id),
      title: String(r.title ?? "Korta gel!"),
      body: String(r.body ?? ""),
      data: {
        tab: "alerts",
        type: String(r.type ?? ""),
        action_id: String(r.action_id ?? ""),
      },
    };
  }

  if (table === "messages") {
    const to = r.receiver_id as string | null;
    const from = String(r.sender_id);
    if (!to || to === from) return null; // guest chat or a note to self
    const senders = (await db(
      `profiles?select=name&id=eq.${encodeURIComponent(from)}&limit=1`,
    )) as { name: string }[];
    const text = String(r.text ?? "");
    return {
      userId: to,
      title: senders[0]?.name ?? "Yeni mesaj",
      body: text.length > 140 ? `${text.slice(0, 139)}…` : text,
      data: { tab: "messages", sender_id: from },
      tag: `msg-${from}`,
    };
  }

  return null;
}

// ── FCM HTTP v1 ──────────────────────────────────────────────────────────────

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

// Read on first use, so a missing/broken secret shows up as a clear error in
// the logs instead of a function that won't boot.
let account: ServiceAccount | null = null;

function serviceAccount(): ServiceAccount {
  if (account) return account;
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT secret is not set");
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is not a service account key");
  }
  return (account = parsed);
}

async function send(
  token: string,
  push: Push,
): Promise<"sent" | "removed" | "failed"> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount().project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${await googleAccessToken()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: push.title, body: push.body },
          data: push.data,
          android: {
            priority: "HIGH",
            notification: push.tag ? { tag: push.tag } : {},
          },
        },
      }),
    },
  );
  if (res.ok) return "sent";

  const detail = await res.text();
  // The app was uninstalled or the token rotated: forget this device.
  if (res.status === 404 || detail.includes("not a valid FCM registration token")) {
    await db(`push_tokens?token=eq.${encodeURIComponent(token)}`, {
      method: "DELETE",
    });
    return "removed";
  }
  console.error(`FCM ${res.status}: ${detail}`);
  return "failed";
}

// OAuth access token for FCM, signed with the service account key (RS256).
let cachedToken: { value: string; expiresAt: number } | null = null;

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const sa = serviceAccount();
  const encode = (o: unknown) =>
    base64url(new TextEncoder().encode(JSON.stringify(o)));
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`Google token ${res.status}: ${await res.text()}`);
  const body = await res.json();
  cachedToken = { value: body.access_token, expiresAt: now + body.expires_in };
  return cachedToken.value;
}

function base64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
