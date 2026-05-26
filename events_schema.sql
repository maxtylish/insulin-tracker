-- ================================================================
-- Ms.Aududu — Events System Schema
-- Run this in Supabase SQL Editor
-- ================================================================

-- ── 1. app_users ─────────────────────────────────────────────────
-- 用 Google sub 當主鍵，不需要 Supabase Auth
CREATE TABLE IF NOT EXISTS app_users (
  id            TEXT PRIMARY KEY,           -- Google sub
  display_name  TEXT NOT NULL,              -- 囉嗦把拔喵 / 貓谷太太
  email         TEXT,
  avatar_url    TEXT,
  role          TEXT DEFAULT 'member'
    CHECK (role IN ('owner', 'member')),
  last_seen     TIMESTAMPTZ DEFAULT NOW(),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 信任關係：spouse 可以互看對方的 visibility='spouse' 事件
-- 目前兩人為固定 hardcode，未來可改為 table
-- owner role = 囉嗦把拔喵


-- ── 2. events ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
  -- Identity
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Content
  title             TEXT NOT NULL,
  description       TEXT,
  note              TEXT,
  
  -- Timing
  start_date        DATE,
  start_time        TIME,
  end_date          DATE,
  end_time          TIME,
  all_day           BOOLEAN DEFAULT true,
  
  -- Ownership
  created_by        TEXT NOT NULL,           -- display_name（囉嗦把拔喵）
  owner_user_id     TEXT NOT NULL,           -- Google sub
  
  -- Sharing
  visibility        TEXT DEFAULT 'spouse'
    CHECK (visibility IN ('private', 'spouse', 'family', 'public')),
  
  -- Classification
  category          TEXT DEFAULT 'general'
    CHECK (category IN ('health', 'general', 'family', 'ai', 'timetree')),
  source_type       TEXT DEFAULT 'app'
    CHECK (source_type IN ('app', 'google', 'timetree', 'ai')),
  tags              TEXT[] DEFAULT '{}',
  
  -- Google Calendar Sync
  sync_google       BOOLEAN DEFAULT false,
  google_event_id   TEXT,
  sync_status       TEXT DEFAULT 'pending'
    CHECK (sync_status IN ('pending', 'synced', 'failed', 'conflict')),
  synced_at         TIMESTAMPTZ,
  
  -- State
  completed         BOOLEAN DEFAULT false,
  completed_at      TIMESTAMPTZ,
  deleted_at        TIMESTAMPTZ,            -- soft delete
  
  -- Metadata
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS events_owner_idx      ON events(owner_user_id);
CREATE INDEX IF NOT EXISTS events_date_idx       ON events(start_date);
CREATE INDEX IF NOT EXISTS events_visibility_idx ON events(visibility);
CREATE INDEX IF NOT EXISTS events_sync_idx       ON events(sync_status) WHERE sync_google = true;
CREATE INDEX IF NOT EXISTS events_active_idx     ON events(start_date) WHERE deleted_at IS NULL;

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS events_updated_at ON events;
CREATE TRIGGER events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ── 3. RLS Policies ──────────────────────────────────────────────
-- 注意：本 app 使用 anon key + owner_user_id 過濾，
-- 暫時不啟用 RLS（與現有 insulin_records 一致）
-- 未來可加：
-- ALTER TABLE events ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "users see own + shared" ON events FOR SELECT
--   USING (
--     owner_user_id = current_setting('app.user_id', true)
--     OR visibility IN ('family', 'public')
--     OR (visibility = 'spouse' AND current_setting('app.user_id', true) = ANY(ARRAY[
--       'HUSBAND_SUB', 'WIFE_SUB'  -- fill in actual Google subs
--     ]))
--   );


-- ── 4. Migration: insulin_todos → events ─────────────────────────
-- 執行前先確認 insulin_records 裡有 todos 欄位
-- 此 migration 由 JS 在首次啟動時自動執行（見 App code）
-- 手動備份用：
-- SELECT todos FROM insulin_records WHERE todos IS NOT NULL;

