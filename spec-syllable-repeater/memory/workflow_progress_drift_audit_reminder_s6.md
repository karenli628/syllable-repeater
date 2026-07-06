id: WF-20260706-progress-drift-audit-reminder-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-6/S6-7 ProgressEngine persistence + hard-guardrails #22
context: 7.4/7.5 Domain 已有 ProgressEngine merge/state machine，但真 Drift adapter、7.6 reminderConfig、#22 Audit Log 尚未落地。#22 原本是 REJECTED_NEEDS_IMPLEMENTATION，處理前必須先用 hard-guardrails skill 並取得使用者對 schema/持久化方案的確認；不能把 audit 資料塞進 `.aboprogress`、ProgressSnapshot 或 app_settings 的雜湊欄位。
action: 使用者 2026-07-06 確認採 Drift `audit_log` 表後，新增 V2 schema 與 `AuditLogEntry` / `AuditLogSink`。`ProgressRepository` 擴充 `saveGroup`、`load/saveReminderConfig` 並實作 `DriftProgressRepository`：`saveProgressSnapshot` 用 transaction 套用 snapshot、`saveGroup/findGroup` 保存 status/archivedAt、reminder 三參數寫 `app_settings`，audit 寫 `audit_log`。`ProgressEngine.archive/restore/setReminderConfig` 與 `AIService.configure` 寫 audit；`AuditLogEntry` 拒絕 key/secret/password/credential/audio/recording/path 等敏感字樣。App 端新增 `ProgressService`、Library dueList、ProgressSettingsScreen（含 `.aboprogress` 匯入/匯出 file picker + MergeSummary 對話框）與 SettleBar 可測 UI slice。
result: `flutter test packages/domain/test` 78/78 綠；`flutter test packages/infra/test` 66/66 綠（2 sidecar integration skips）；`cd app && flutter test` 52/52 綠；`flutter analyze` No issues。hard-limits-matrix #22 從 `REJECTED_NEEDS_IMPLEMENTATION` 轉 `PARTIAL`，#27 Soft Delete 轉 `IMPLEMENTED`，預期 guardrails checker 只剩 #9 Branch Protection 會擋交付。
reasoning: Domain 仍是 merge policy / 168h 狀態機 / reminder 預設的唯一規則來源；Drift adapter 只負責持久化與 transaction，避免 infra/UI 重寫 updatedAt、contentHash reset 或 archive window。Audit log 獨立成表可讓 #22 成為可查的硬防線，同時不污染 pack/progress 匯出格式，也維持 M10 不寫 key/audio/path。
recommendation: FP7 歸檔 UI 已接 `ProgressEngine.archive/restore`，後續調整仍不得自行改 DB 或重寫 168h window；`.aboprogress` 匯入/匯出已接，若要調整體驗仍不得在 UI 再做 merge。接真 AI provider/Keychain 時必須讓 `AIService.configure` 走同一 audit sink，並保持 key 明文只進 SecureStore，不進 audit/log/DB/pack/progress。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
