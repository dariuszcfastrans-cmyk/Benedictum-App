-- ============================================================
-- Benedictum — migracja inicjalna (Część C2)
-- Tabele + RLS + atomowa funkcja RPC rate-limit.
-- ============================================================

-- ------------------------------------------------------------
-- profiles
-- ------------------------------------------------------------
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  display_name text,
  preferred_language text DEFAULT 'pl'
);
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_own" ON profiles FOR ALL USING (auth.uid() = id);

-- ------------------------------------------------------------
-- sessions
-- ------------------------------------------------------------
CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  scenario_key text,
  title text,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sessions_own" ON sessions FOR ALL USING (auth.uid() = user_id);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- ------------------------------------------------------------
-- messages (struktura pod przyszłość, NIE używana w MVP do zapisu transkryptów)
-- ------------------------------------------------------------
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES sessions(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  sender text,
  content text,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "messages_own" ON messages FOR ALL USING (auth.uid() = user_id);
CREATE INDEX idx_messages_user_id ON messages(user_id);

-- ------------------------------------------------------------
-- reports
-- ------------------------------------------------------------
CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES sessions(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  strengths text,
  gaps text,
  action_items text,
  overall_rating int CHECK (overall_rating BETWEEN 1 AND 5),
  created_at timestamptz DEFAULT now()
);
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reports_own" ON reports FOR ALL USING (auth.uid() = user_id);
CREATE INDEX idx_reports_user_id ON reports(user_id);

-- ------------------------------------------------------------
-- rate_limits (tabela serwisowa, BEZ RLS)
-- ------------------------------------------------------------
CREATE TABLE rate_limits (
  user_id uuid PRIMARY KEY,
  window_start timestamptz NOT NULL,
  request_count integer NOT NULL DEFAULT 1,
  updated_at timestamptz DEFAULT now()
);
REVOKE ALL ON rate_limits FROM anon, authenticated;

-- ------------------------------------------------------------
-- Funkcja RPC atomowa (SECURITY DEFINER)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_rate_limit(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_window_start timestamptz;
  v_count int;
  v_allowed boolean := false;
  v_remaining int := 0;
BEGIN
  INSERT INTO rate_limits (user_id, window_start, request_count)
  VALUES (p_user_id, now(), 1)
  ON CONFLICT (user_id) DO UPDATE SET
    request_count = CASE
      WHEN rate_limits.window_start > now() - interval '1 minute'
      THEN rate_limits.request_count + 1
      ELSE 1
    END,
    window_start = CASE
      WHEN rate_limits.window_start > now() - interval '1 minute'
      THEN rate_limits.window_start
      ELSE now()
    END,
    updated_at = now()
  RETURNING request_count, window_start INTO v_count, v_window_start;

  IF v_count <= 5 THEN
    v_allowed := true;
    v_remaining := 5 - v_count;
  ELSE
    v_allowed := false;
    v_remaining := 0;
  END IF;

  RETURN json_build_object('allowed', v_allowed, 'remaining', v_remaining);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_rate_limit(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(uuid) TO service_role;
