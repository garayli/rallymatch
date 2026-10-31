-- Let a player tell the requester that their match request was accepted or
-- declined (and an organiser tell a player they were removed from a lobby).
-- Run once in the Supabase SQL editor. Idempotent.
--
-- Until now the only INSERT policy on notifications was "Requester can
-- notify opponent of match request" (type = matchRequest). The app's
-- _notifyRequesterOfResponse / removeFromLobby inserts were refused by RLS
-- (42501) and swallowed, so requesters never heard back — and now that every
-- notification row is also a push, they got no push either.
--
-- Scope: only matchConfirmed / matchDeclined, only to player1 of that match,
-- and only by its player2 (the one who answers; for a lobby, the organiser).

DROP POLICY IF EXISTS "Opponent can notify requester of response" ON public.notifications;
CREATE POLICY "Opponent can notify requester of response" ON public.notifications
  FOR INSERT
  WITH CHECK (
    type IN ('matchConfirmed'::public.notif_type, 'matchDeclined'::public.notif_type)
    AND EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id::text = notifications.action_id
        AND m.player1_id = notifications.user_id
        AND m.player2_id = auth.uid()
    )
  );
