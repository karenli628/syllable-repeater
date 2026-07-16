-- AI-Generate
-- Drift schema V3：v1.1 最近標籤檔索引（backend-design.md §3.1.1、REQ-11、OQ-6）
-- M10：只保存索引資訊，不保存音訊 bytes、PCM、錄音或 blob。

CREATE TABLE IF NOT EXISTS label_registry (
    audio_fingerprint TEXT PRIMARY KEY,
    label_path TEXT NOT NULL,
    segment_count INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
