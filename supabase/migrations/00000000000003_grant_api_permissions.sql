-- ============================================================
-- Benedictum — migracja Fala 2A.2 (Q1, wariant a) — uzupełnienie grantów
-- Defekt migracji 01: tabele nie miały GRANT dla ról API → PostgREST
-- odrzucał request przed RLS (42501). To naprawa, nie nowe wymaganie.
-- ============================================================
-- Zasady (dyrektywa 2A §18 + decyzja Operatora):
--   authenticated : SELECT, INSERT, UPDATE, DELETE  (ścieżka RLS klienta)
--   service_role  : SELECT, INSERT, DELETE (BEZ UPDATE) (ścieżka session-proxy;
--                   session-proxy nie modyfikuje istniejących wierszy w 2A.2)
--   anon          : REVOKE ALL (defense in depth — anon nie dotyka danych)
-- Tabele używają gen_random_uuid() (id uuid PK DEFAULT), nie sequences
-- → NIE grantujemy sekwencji.
-- Zero zmian: schematu tabel, RLS policies, kontraktów 2A.2.
-- ============================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sessions  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reports   TO authenticated;

GRANT SELECT, INSERT, DELETE ON public.sessions  TO service_role;
GRANT SELECT, INSERT, DELETE ON public.messages  TO service_role;
GRANT SELECT, INSERT, DELETE ON public.reports   TO service_role;

REVOKE ALL ON public.sessions  FROM anon;
REVOKE ALL ON public.messages  FROM anon;
REVOKE ALL ON public.reports   FROM anon;