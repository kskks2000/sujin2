BEGIN;

ALTER TABLE tms.app_users
  ADD COLUMN IF NOT EXISTS password_hash TEXT;

ALTER TABLE tms.app_users
  ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;

UPDATE tms.app_users
SET password_hash = crypt('Sujin2026!', gen_salt('bf'))
WHERE is_active = TRUE
  AND password_hash IS NULL
  AND lower(email) IN (
    'admin@sujin.local',
    'ops@sujin.local',
    'dispatch@sujin.local'
  );

COMMIT;
