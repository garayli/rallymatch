-- In-app "Delete account" (Google Play policy). Run once in the Supabase SQL
-- editor. Idempotent.
--
-- The app calls rpc('delete_my_account'). It runs as the table owner so it can
-- remove the auth.users row, which cascades to profiles, lobbies, notifications,
-- push_tokens, reviews (both sides), matches (player1/player2) and sent messages.
-- Foreign keys left to cascade are listed in ADR-014; this function only does
-- what cascades can't:
--   * tell the other players their lobby/match is gone,
--   * delete received messages (messages.receiver_id is SET NULL, which would
--     leave the sender's half of the chat behind with no receiver),
--   * delete matches BEFORE the profile, because matches.winner_id and
--     matches.result_logged_by are NO ACTION and would block the profile delete.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid  uuid := auth.uid();
  me   text;
  m    record;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in';
  END IF;

  SELECT name INTO me FROM public.profiles WHERE id = uid;

  -- 1. Close my open lobbies. lobby_on_close_trg cancels the pending requests
  --    and notifies each requester ("Lobi Kapandı").
  UPDATE public.lobbies SET status = 'closed'
   WHERE creator_id = uid AND status IN ('open', 'full');

  -- 2. Upcoming matches that are still alive (pending or confirmed) with a
  --    registered opponent: tell them, and retire any Kabul/Reddet card.
  FOR m IN
    SELECT id, CASE WHEN player1_id = uid THEN player2_id ELSE player1_id END AS other_id
      FROM public.matches
     WHERE (player1_id = uid OR player2_id = uid)
       AND status IN ('pending', 'confirmed')
       AND date_time > now()
  LOOP
    CONTINUE WHEN m.other_id IS NULL OR m.other_id = uid;
    INSERT INTO public.notifications (user_id, type, title, body, action_id)
      VALUES (m.other_id, 'matchDeclined', 'Maç İptal Edildi',
              coalesce(me, 'Rakibin') || ' hesabını sildi, maç iptal edildi.', m.id::text);
    UPDATE public.notifications
       SET type = 'matchDeclined', title = 'İstek Sona Erdi', is_read = true
     WHERE user_id = m.other_id AND type = 'matchRequest' AND action_id = m.id::text;
  END LOOP;

  -- 3. Messages I received (sent ones cascade with the profile).
  DELETE FROM public.messages WHERE receiver_id = uid;

  -- 4. Every match I played or logged. lobby_recount_match_trg keeps the
  --    counters of other players' lobbies right.
  DELETE FROM public.matches
   WHERE player1_id = uid OR player2_id = uid
      OR winner_id = uid OR result_logged_by = uid;

  -- 5. The account. Cascades to the rest.
  DELETE FROM auth.users WHERE id = uid;
END $$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

NOTIFY pgrst, 'reload schema';
