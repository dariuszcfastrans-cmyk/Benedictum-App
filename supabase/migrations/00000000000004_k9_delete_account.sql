-- ============================================================
-- Benedictum — migracja K9 (B2): usuwanie konta
-- 1) ON DELETE CASCADE na wszystkich FK do auth.users(id)
--    (usunięcie wiersza auth.users kasuje dane użytkownika).
-- 2) RPC public.delete_my_account() (SECURITY DEFINER):
--    kasuje rate_limits + auth.users bieżącego użytkownika.
--    Uprawnienie wyłącznie dla authenticated (ścieżka klienta).
-- rate_limits NIE ma FK do auth.users (świadomie, tabela serwisowa)
-- → czyszczona jawnie w funkcji.
-- ============================================================

-- ------------------------------------------------------------
-- 1) CASCADE na FK do auth.users
-- ------------------------------------------------------------
ALTER TABLE profiles
  DROP CONSTRAINT profiles_id_fkey,
  ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE sessions
  DROP CONSTRAINT sessions_user_id_fkey,
  ADD CONSTRAINT sessions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE messages
  DROP CONSTRAINT messages_user_id_fkey,
  ADD CONSTRAINT messages_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE reports
  DROP CONSTRAINT reports_user_id_fkey,
  ADD CONSTRAINT reports_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ------------------------------------------------------------
-- 2) RPC usuwania konta
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM rate_limits WHERE user_id = auth.uid();
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
