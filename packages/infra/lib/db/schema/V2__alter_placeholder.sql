-- AI-Generate
-- V2：hard-limits-matrix #22 Audit Log（使用者 2026-07-06 確認採 Drift audit_log table）

CREATE TABLE audit_log (
    id TEXT PRIMARY KEY,
    occurred_at INTEGER NOT NULL,        -- epoch ms（UTC）
    actor TEXT NOT NULL,                 -- local-user
    action TEXT NOT NULL,                -- reminder_config_changed / ai_credential_configured / ...
    target_type TEXT NOT NULL,           -- app_settings / ai_service / practice_group
    target_id TEXT,                      -- 非敏感識別，不放 API key / 路徑
    metadata_json TEXT NOT NULL          -- 非敏感摘要 JSON
);

CREATE INDEX idx_audit_log_time ON audit_log(occurred_at);
CREATE INDEX idx_audit_log_action ON audit_log(action);
