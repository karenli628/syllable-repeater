-- AI-Generate
-- Drift schema V1 等效 SQL（權威定義在 lib/src/db/app_database.dart；本檔供審查與追溯）
-- 對照 backend-design.md §3.1.2；OQ-3 已由使用者核可（2026-07-04）

CREATE TABLE lesson_registry (
    id TEXT PRIMARY KEY,                 -- Lesson UUID
    pack_path TEXT NOT NULL,             -- .abopack 最後已知路徑
    title TEXT NOT NULL,
    content_hash TEXT NOT NULL,          -- M6 局部重置依據
    updated_at INTEGER NOT NULL          -- epoch ms（UTC）
);

CREATE TABLE practice_group (
    id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    lesson_id TEXT NOT NULL REFERENCES lesson_registry(id),
    name TEXT NOT NULL,
    config_json TEXT NOT NULL,           -- stepRange、repeatN 等
    status TEXT NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE|ARCHIVED|EXPIRED
    archived_at INTEGER,                 -- M8 168h 起算點
    updated_at INTEGER NOT NULL          -- M6 upsert 比較鍵
);
CREATE INDEX idx_pg_sync_key ON practice_group(profile_id, course_id, lesson_id);
CREATE INDEX idx_pg_status ON practice_group(status);

CREATE TABLE srs_state (
    group_id TEXT PRIMARY KEY REFERENCES practice_group(id),
    interval_index INTEGER NOT NULL DEFAULT 0,  -- 間隔序列 0/1/3/7/14/30（天）
    next_due INTEGER NOT NULL,                  -- epoch ms
    difficulty TEXT NOT NULL DEFAULT 'NORMAL',  -- HARD|NORMAL|EASY
    updated_at INTEGER NOT NULL
);
CREATE INDEX idx_srs_due ON srs_state(next_due);

CREATE TABLE attempt (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES practice_group(id),
    step_index INTEGER NOT NULL,
    rhythm_delta REAL NOT NULL,
    intonation_delta REAL NOT NULL,
    overlay_json TEXT NOT NULL,          -- M10：只存快照，絕不存音訊
    created_at INTEGER NOT NULL
);
CREATE INDEX idx_attempt_group ON attempt(group_id, created_at);

CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,                -- 如 reminder.minutes / sidecar.timeoutSec
    value TEXT NOT NULL
);

-- V1 無 audit_log；#22 Audit Log 由 V2__alter_placeholder.sql 建立。
