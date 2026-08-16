-- ============================================================
-- Benedictum — migracja Fala 2A.2 (Q1, wariant a)
-- ON DELETE CASCADE: usunięcie sesji usuwa messages + reports.
-- Zero innych zmian schematu (bez JSONB, bez nowych tabel/kolumn).
-- Uzasadnienie (dyrektywa 2A §18, Q1): DELETE own jest MUST;
-- domyślne NO ACTION blokowało usunięcie sesji z dziećmi.
-- ============================================================

ALTER TABLE messages
  DROP CONSTRAINT messages_session_id_fkey,
  ADD CONSTRAINT messages_session_id_fkey
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;

ALTER TABLE reports
  DROP CONSTRAINT reports_session_id_fkey,
  ADD CONSTRAINT reports_session_id_fkey
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;