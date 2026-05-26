-- ================================================================
-- Ms.Aududu — ev_store 跨裝置事件同步表
-- 在 Supabase SQL Editor 執行此指令
-- ================================================================

CREATE TABLE IF NOT EXISTS ev_store (
  id          TEXT PRIMARY KEY,          -- 事件唯一 ID（ev_TIMESTAMP_XXXXX）
  family_id   TEXT NOT NULL,             -- 同 insulin_records 的 user_id（兩台手機填同一個）
  data        JSONB NOT NULL,            -- 完整事件 JSON 物件
  updated_at  TIMESTAMPTZ DEFAULT NOW()  -- 用於合併衝突判斷
);

CREATE INDEX IF NOT EXISTS ev_store_family_idx ON ev_store(family_id);
