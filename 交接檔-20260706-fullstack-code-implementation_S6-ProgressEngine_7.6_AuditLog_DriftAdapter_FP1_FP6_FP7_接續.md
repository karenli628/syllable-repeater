# 交接檔 - 2026-07-06 - fullstack-code-implementation / S6 FP1/FP6/FP7 hydrate + settings 收尾

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / S6 收尾
> 用途：讓下一個 session 接續 #9 / 真 adapter / review，不重做 7.1-7.6 Domain/Infra 或 FP1/FP6/FP7 可測 UI。

## 0. 一句話結論

本 session 已完成 S6 主要可測實作：7.4/7.5/7.6 Domain+Infra、#22 Audit Log Drift table、FP1 Library dueList/課件入口、FP6 `.abopack` open/save + lesson hydrate + ⌘O/⌘S、SettleBar 真 PracticeGroup linkage、FP7 progress export/import + MergeSummary + archive/restore UI + reminder/AI key/sidecar timeout settings，以及 S6 round-trip widget slice。最新 code 回歸：Domain 82/82、Infra 67/67（2 sidecar skips）、App 58/58；guardrails checker 只剩 #9 Branch Protection（本機無 remote，不能假完成）。

## 1. 新 session 必讀順序

1. 共通記憶與偏好：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`
2. 本專案 memory（Precision > Recall，建議 5 條）：
   - `spec-syllable-repeater/memory/workflow_fp6_pack_service_practicegroup_linkage_s6.md`
   - `spec-syllable-repeater/memory/workflow_fp6_lesson_hydrate_shortcuts_s6.md`
   - `spec-syllable-repeater/memory/workflow_fp7_ai_key_sidecar_settings_s6.md`
   - `spec-syllable-repeater/memory/workflow_fp1_fp7_library_archive_ui_s6.md`
   - `spec-syllable-repeater/memory/workflow_progress_drift_audit_reminder_s6.md`
   - `spec-syllable-repeater/memory/workflow_ai_service_domain_guardrails_ports.md`
   - `spec-syllable-repeater/memory/pitfall_riverpod_session_source_null_equality.md`
3. 本交接檔。
4. 規格與任務：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`（功能點 1/6/7）
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`（§3.2.6、§3.1.2）
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`

## 2. 本 session 已完成

- 7.4 真 Drift adapter 接線：
  - `DriftProgressRepository.saveProgressSnapshot` 以 transaction 套用 `.aboprogress` snapshot。
  - 保留既有 `lesson_registry.pack_path/title`，merge 規則仍由 Domain `ProgressEngine` 決定。
- 7.5 archive/restore：
  - Domain `ProgressEngine.archive/restore` 完成 CT-08（167h/169h）。
  - Drift adapter 保存 `practice_group.status/archived_at`。
  - archive/restore/restore expired 寫 `audit_log`。
- 7.6 reminderConfig：
  - `ReminderConfig.defaults = 15/5/2`。
  - Drift adapter 以 `app_settings` 儲存 `reminder.minutes` / `reminder.failCap` / `reminder.dailySessions`。
  - App `ProgressSettingsScreen` 可讀寫提醒三參數。
- 8.4.2 #22 Audit Log：
  - 使用者確認採 Drift `audit_log` 表後實作 V2 schema。
  - `AuditLogEntry` / `AuditLogSink` 已落地，敏感 token（key/secret/password/credential/audio/recording/path）拒絕。
  - `ProgressEngine.archive/restore/setReminderConfig` 與 `AIService.configure` 寫 audit。
  - hard-limits-matrix #22 轉 `PARTIAL`；#27 Soft Delete 轉 `IMPLEMENTED`。
- 前端可測 slice：
  - FP1：`LibraryScreen` 顯示 dueList 與 `lesson_registry` 課件清單入口，無逾期/懲罰文案，課件卡可切到練習/編輯 tab。
  - FP6：manual translation shell，自動翻譯鈕未設 key 停用＋tooltip；`lesson_pack_service.dart` 以 `LessonPackEngine + AtomicFileIo + file_selector` 真開啟/儲存 `.abopack`，成功後同步 `lesson_registry`，損毀 pack 不覆蓋現有譯文。
  - FP6/FP1 hydrate：`lesson_session_controller.dart` 會把 `.abopack` Lesson 解碼成 PCM/peaks；課件卡、開啟、儲存都會 hydrate；editor/practice 以 `sourceLessonId` 防止 analysis result 誤用 pack session；FP6 panel 已接 ⌘O/⌘S 與 Ctrl+O/Ctrl+S。
  - FP7：progress export/import file picker、MergeSummary 對話框、reminder settings screen、歸檔確認、ARCHIVED 168h 倒數、EXPIRED disabled、恢復入口。
  - FP7 settings：AI key obscure field 送 `AIService.configure` 後清空欄位，目前只用 `InMemoryAiSecureStore` + `NoopAiClient`；sidecar timeout 存 `app_settings` key `sidecar.timeoutSec` 並寫 audit。
  - Practice：`SettleBar` 三難度按鈕先 `ensurePracticeGroup` 再呼叫 `ProgressService.settle`，成功後顯示 nextDue；`DriftProgressRepository.saveGroup` 可替未註冊 lesson 建最小 registry row。

## 3. 同階段後續執行項目順序

1. **8.4.1 #9 Branch Protection（保留到最後）**
   - 使用者最新指示：GitHub 上載若非必要保留到最後。
   - 需要 GitHub repo/main branch 狀態；不能用本機檔案假裝完成。
   - review/archive/push 前 guardrails checker 仍會因 #9 擋交付。
2. **7.2 真 HTTP/Keychain adapter**
   - 仍待 provider/key 安全路徑回報；未確認前只保留 Domain ports + in-memory app slice。
   - 接線時不得繞過 `AIService.configure/translate`、rate limit、HTTPS host allowlist、prompt injection guard 與 audit sink。
3. **8.2 CT-09 授權掃描與 9.1/9.2 release gate**
   - CT-09 本機授權 gate 已補：`scripts/check_licenses.py`、`scripts/test_check_licenses.py`、`release/license-manifest.json`、`release/release-checklist.md`。
   - 仍需完成免簽章 Gatekeeper 說明、macOS release build/實機檢查與 GitHub 最後 gate。
4. **fullstack-code-review**
   - S6 code 面完成後，下一個流程階段應用 `fullstack-code-review` 對照 design/task/guardrails 做審查；#9 若仍未處理，報告需列為外部阻塞。
5. **project-archive / ops-monitoring**
   - review 通過後再進 `project-archive`；歸檔完成後再進 `ops-monitoring`。

## 4. 驗證紀錄

```text
flutter test packages/domain/test
-> 82/82 passed

flutter test packages/infra/test
-> 67/67 passed, 2 sidecar integration skips

cd app && flutter test
-> 58/58 passed

flutter analyze
-> No issues found

git diff --check
-> passed

python3 scripts/check_guardrails.py spec-syllable-repeater/.../hard-limits-matrix.md spec-syllable-repeater/.../decision-log.md
-> expected fail: only #9 Branch Protection remains

python3 scripts/check_licenses.py spec-syllable-repeater/.../release/license-manifest.json
-> passed, 18 components

python3 -m unittest scripts/test_check_licenses.py
-> 6/6 passed
```

## 5. 不要做

- 不要重做 7.1/7.2/7.3/7.4/7.5/7.6 Domain/Infra。
- 不要在 UI 或 infra 重寫 `updatedAt`/`contentHash` merge policy 或 168h archive window。
- 不要新增 overdue/failed/penalty 欄位；M7 跨日零懲罰仍是硬限制。
- 不要把 key/audio/本機絕對路徑寫入 pack/progress/DB audit metadata/log。
- 不要關 macOS Sandbox；目前使用者明確要求不要關。
- 不要 push guardrails 未通過的分支；#9 未完成前 pre-push/checker 會擋。
- 不要在未確認 provider/key 路徑前實作真 HTTP/Keychain adapter。
