-- Push notifications: one row per device token (FCM), owned by the player
-- signed in on that device. Run once in the Supabase SQL editor. Idempotent.
--
-- The app never touches the table directly: register_push_token /
-- unregister_push_token run as the table owner, so a phone that switches
-- accounts can move its token to the new player (a plain upsert would hit
-- the old owner's row and fail RLS). The `push` edge function reads tokens
-- with the service role, which bypasses RLS.

-- ── 1. Table ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.push_tokens (
  token      text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform   text NOT NULL DEFAULT 'android',
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS push_tokens_user_id_idx ON public.push_tokens (user_id);

-- RLS on with no policies: no direct reads or writes from the app.
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- ── 2. Register / unregister ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.register_push_token(p_token text, p_platform text DEFAULT 'android')
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_signed_in';
  END IF;
  IF p_token IS NULL OR length(p_token) < 20 OR length(p_token) > 4096 THEN
    RAISE EXCEPTION 'bad_token';
  END IF;
  INSERT INTO public.push_tokens (token, user_id, platform, updated_at)
  VALUES (p_token, auth.uid(), coalesce(p_platform, 'android'), now())
  ON CONFLICT (token) DO UPDATE
    SET user_id = auth.uid(), platform = excluded.platform, updated_at = now();
END $$;

CREATE OR REPLACE FUNCTION public.unregister_push_token(p_token text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM public.push_tokens WHERE token = p_token AND user_id = auth.uid();
END $$;

REVOKE ALL ON FUNCTION public.register_push_token(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unregister_push_token(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_push_token(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_push_token(text) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── 3. Sending (set up in the dashboard, not here) ───────────────────────────
-- Database → Webhooks: two webhooks, INSERT on public.notifications and
-- INSERT on public.messages → Supabase Edge Function `push`, with the HTTP
-- header `x-push-secret` = the PUSH_WEBHOOK_SECRET edge function secret.
-- Steps in docs/project_notes/key_facts.md → Push notifications.
