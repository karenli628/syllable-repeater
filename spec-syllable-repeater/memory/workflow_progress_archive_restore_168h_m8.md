id: WF-20260706-progress-archive-restore-168h-m8
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-5 ProgressEngine 7.5
context: 7.5 要落地 M8 歸檔狀態機：ACTIVE 可歸檔，ARCHIVED 在不滿 168h 內可恢復，滿 168h 後不可逆 EXPIRED；同時 M7 要求 dueList 不寫狀態，#22 Audit Log 尚未確認 schema，不能順手新增 audit table 或操作紀錄。
action: 先在 Domain 層用 TDD 鎖住狀態機：新增 `packages/domain/test/progress_archive_test.dart`，再於 `ProgressEngine` 實作 `archive/restore`，並在 `ProgressRepository` 增加 `saveGroup` port。`archive` 只允許 ACTIVE -> ARCHIVED 並寫 `archivedAt=clock.now()`；`restore` 使用注入 Clock 判定 `now - archivedAt >= 168h` 時保存 EXPIRED 後拋 `ERR_ARCHIVE_RESTORE_EXPIRED`，167h 內回 ACTIVE 並清 `archivedAt`。`dueList` 仍只排除非 ACTIVE，不做 EXPIRED 惰性寫入。
result: `flutter test packages/domain/test/progress_archive_test.dart` 4/4 綠，`flutter test packages/domain/test` 74/74 綠，`flutter analyze` No issues，`git diff --check` 通過。`task-split.md` 與 `execution-log.md` 已補 7.5 Domain 可測部分完成；guardrails checker 仍因 #9/#22 預期失敗。
reasoning: 把 168h 判定放在 `restore` 而非 `dueList`，可同時滿足 M8 的不可逆狀態轉換與 M7「到期查詢不寫狀態、不施加懲罰」。過期時保存 EXPIRED 後丟錯，讓使用者看到恢復失敗，也讓後續 UI/DB 不會一直停在可恢復的 ARCHIVED 假象。
recommendation: 後續接 Drift adapter 時，`saveGroup` 必須在交易中更新 `practice_group.status/archived_at/updated_at`；若要寫操作紀錄，必須先依 #22 取得 audit log 持久化方案確認。不要在 `dueList` 或 UI 層重寫 168h 規則，也不要新增 overdue/failed/penalty 欄位。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
