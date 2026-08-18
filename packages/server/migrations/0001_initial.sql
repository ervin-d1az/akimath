-- 0001_initial · the schema freezes here (F1).
--
-- FORWARD-ONLY. Once this file has been applied anywhere, it is history: a
-- column is added by a new file and never by editing this one. The runner
-- refuses to start if this file's checksum stops matching what it recorded.
--
-- The runner wraps each file in its own transaction, so this file contains no
-- BEGIN/COMMIT of its own.

-- `schema_migrations` is deliberately NOT created here. The ledger belongs to
-- the runner, which creates it before it can read it — a migration cannot
-- create the table that records whether that migration ran. Found by applying
-- this file to a real database, which is the only place the ordering shows.

-- ---------------------------------------------------------------------------
-- Roles.
--
-- `app_request` serves the request path. `retention_job` runs BOTH the nightly
-- retention job and the erasure path `DELETE /v1/me` — ARCHITECTURE.md:242 puts
-- them under the same role, which is why its DELETE grants below are wider than
-- the nightly job uses.
--
-- Created without LOGIN: passwords and connection strings are the environment's
-- business, not the schema's. A deployment grants one of these to the user it
-- connects as.
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_request') THEN
    CREATE ROLE app_request NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'retention_job') THEN
    CREATE ROLE retention_job NOLOGIN;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- players
--
-- Identity is the client's: the app mints a UUIDv7 at first launch so phase-2
-- attempts have a foreign key with no server involved (ARCHITECTURE.md §5).
-- There is therefore NO DEFAULT here — a row with a server-minted id would be a
-- row the device cannot match.
--
-- NO NAME AND NO DATE OF BIRTH, anywhere in this schema. `age_band` is the only
-- thing recorded about who a player is, it is NOT NULL, and it is resolved
-- before the device obtains any session — a guest writes this row at first
-- sync, before any account exists, so a band collected at `1.2 Crear cuenta`
-- would arrive after the row.
--
-- A CHECK and not an enum: the band set is Gate A's to confirm, and replacing a
-- CHECK is one forward-only statement while an enum value can never be removed.
-- ---------------------------------------------------------------------------

CREATE TABLE players (
  id          uuid        PRIMARY KEY,
  age_band    text        NOT NULL
                          CONSTRAINT players_age_band_known
                          CHECK (age_band IN ('under_13', '13_17', 'adult')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- issued_items · what the server emitted, so it can rederive it years later.
--
-- The prompt travels rendered; `template_id`, `template_version` and `seed`
-- never appear in a response (ARCHITECTURE.md §4). They live here.
-- ---------------------------------------------------------------------------

CREATE TABLE issued_items (
  id                uuid        PRIMARY KEY,
  player_id         uuid        NOT NULL REFERENCES players (id) ON DELETE CASCADE,
  template_id       text        NOT NULL,
  template_version  integer     NOT NULL,
  seed              bigint      NOT NULL,
  ladder_step       smallint    NOT NULL,
  issued_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX issued_items_player_idx ON issued_items (player_id);

-- ---------------------------------------------------------------------------
-- offline_packs · one row per pack, not one per item.
--
-- The server must be able to revalidate every offline item; the data model
-- cannot pay four downloads a day times fifty rows (ARCHITECTURE.md §4). A
-- manifest satisfies both. Item identity is (pack_id, index) — there is
-- deliberately no per-item table, and a test enumerates the schema to keep it
-- that way.
-- ---------------------------------------------------------------------------

CREATE TABLE offline_packs (
  id             uuid        PRIMARY KEY,
  player_id      uuid        NOT NULL REFERENCES players (id) ON DELETE CASCADE,
  skill_id       smallint,
  template_refs  jsonb       NOT NULL,
  pack_salt      bytea       NOT NULL,
  issued_at      timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL
);

CREATE INDEX offline_packs_player_idx ON offline_packs (player_id);

-- ---------------------------------------------------------------------------
-- attempts · append-only.
--
-- "`attempts` never accepts UPDATE. It accepts DELETE only through the erasure
-- path (`DELETE /v1/me`) and the retention job, both under the `retention_job`
-- role. The request path holds no DELETE grant on `attempts`."
-- — ARCHITECTURE.md:242, restated in CLAUDE.md.
--
-- The grants at the bottom of this file are what make that true. It is not a
-- comment and not a convention.
--
-- An attempt points at an issued item OR at an offline (pack, index) pair, and
-- exactly one of the two. `is_correct` is the SERVER's verdict, recomputed at
-- sync; the sync endpoint accepts no `ok` field from a client, which is what
-- makes the invariant true by construction.
-- ---------------------------------------------------------------------------

CREATE TABLE attempts (
  id               uuid        PRIMARY KEY,
  player_id        uuid        NOT NULL REFERENCES players (id) ON DELETE CASCADE,
  issued_item_id   uuid        REFERENCES issued_items (id) ON DELETE CASCADE,
  pack_id          uuid        REFERENCES offline_packs (id) ON DELETE CASCADE,
  pack_index       smallint,
  skill_id         smallint    NOT NULL,
  is_correct       boolean     NOT NULL,
  elapsed_ms       integer     NOT NULL CHECK (elapsed_ms >= 0),
  answered_at      timestamptz NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT attempts_one_source CHECK (
    (issued_item_id IS NOT NULL AND pack_id IS NULL AND pack_index IS NULL)
    OR
    (issued_item_id IS NULL AND pack_id IS NOT NULL AND pack_index IS NOT NULL)
  )
);

CREATE INDEX attempts_player_answered_idx ON attempts (player_id, answered_at);
CREATE INDEX attempts_created_idx ON attempts (created_at);

-- ---------------------------------------------------------------------------
-- user_skills · the rating, which is the server's exclusive authority.
-- ---------------------------------------------------------------------------

CREATE TABLE user_skills (
  player_id   uuid        NOT NULL REFERENCES players (id) ON DELETE CASCADE,
  skill_id    smallint    NOT NULL,
  rating      real        NOT NULL,
  deviation   real        NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (player_id, skill_id)
);

-- ---------------------------------------------------------------------------
-- template_stats · maintained on write, which is what makes deletion safe.
--
-- Calibration never derives from raw attempt rows, so retention can delete them
-- (ARCHITECTURE.md §5). `sum_expected` and `sum_user_rating` are not optional:
-- without them an 80% success rate is unreadable, because adaptive routing
-- guarantees only strong players ever touch the hard items.
-- ---------------------------------------------------------------------------

CREATE TABLE template_stats (
  template_id       text     NOT NULL,
  template_version  integer  NOT NULL,
  attempts          bigint   NOT NULL DEFAULT 0,
  correct           bigint   NOT NULL DEFAULT 0,
  sum_expected      double precision NOT NULL DEFAULT 0,
  sum_user_rating   double precision NOT NULL DEFAULT 0,
  updated_at        timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (template_id, template_version)
);

-- ---------------------------------------------------------------------------
-- diag_events · one row per diagnosis resolved at sync. Thirty days.
--
-- `misconception_id` is null for the generic non-scolding fallback the pack
-- carries for an answer no labelled distractor anticipated.
-- ---------------------------------------------------------------------------

CREATE TABLE diag_events (
  id                uuid        PRIMARY KEY,
  player_id         uuid        NOT NULL REFERENCES players (id) ON DELETE CASCADE,
  attempt_id        uuid        NOT NULL REFERENCES attempts (id) ON DELETE CASCADE,
  misconception_id  text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX diag_events_created_idx ON diag_events (created_at);

-- ---------------------------------------------------------------------------
-- Grants. These ARE the enforcement.
--
-- Nothing is granted by default beyond what is written here, and no role is
-- given DELETE it does not need. The two rules a test enumerates every table
-- for:
--
--   1. `app_request` holds DELETE on NO table. Erasure does not run under it.
--   2. `retention_job` holds DELETE on every table holding player data, and no
--      INSERT and no UPDATE anywhere.
-- ---------------------------------------------------------------------------

-- USAGE on the schema, stated rather than inherited. A stock `public` schema
-- grants it to PUBLIC by default, so this line changes nothing on a normal
-- database and is the difference between working and not on one where `public`
-- was recreated — which is what the test harness does between runs. A frozen
-- schema should not depend on a default it never wrote down.
GRANT USAGE ON SCHEMA public TO app_request, retention_job;

GRANT SELECT, INSERT ON attempts TO app_request;

GRANT SELECT, INSERT, UPDATE ON players        TO app_request;
GRANT SELECT, INSERT, UPDATE ON issued_items   TO app_request;
GRANT SELECT, INSERT, UPDATE ON offline_packs  TO app_request;
GRANT SELECT, INSERT, UPDATE ON user_skills    TO app_request;
GRANT SELECT, INSERT, UPDATE ON template_stats TO app_request;
GRANT SELECT, INSERT         ON diag_events    TO app_request;

GRANT SELECT, DELETE ON players       TO retention_job;
GRANT SELECT, DELETE ON issued_items  TO retention_job;
GRANT SELECT, DELETE ON offline_packs TO retention_job;
GRANT SELECT, DELETE ON attempts      TO retention_job;
GRANT SELECT, DELETE ON user_skills   TO retention_job;
GRANT SELECT, DELETE ON diag_events   TO retention_job;
