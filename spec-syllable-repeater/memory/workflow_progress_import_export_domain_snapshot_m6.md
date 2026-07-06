id: WF-20260706-progress-import-export-domain-snapshot-m6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-4 ProgressEngine 7.4
context: 7.4 要做 `.aboprogress` 匯入/匯出，核心防線是 M6：updatedAt 較新覆寫、相等冪等、Lesson contentHash 變更只 reset 該 Lesson；同時不能新增 #22 Audit Log schema，因 8.4.2 標 `[必須確認]`。若把交易/Drift schema 先硬塞進 Domain，會破壞 M5；若只寫文件則 CT-06 沒有真防線。
action: 先在 Domain 落地平台中立 snapshot 與 merge policy：新增 `ProgressSnapshot` / `MergeSummary`，`ProgressEngine.exportProgress/importProgress` 透過 `FileIo` 讀寫 schemaVersion=1 JSON；`importProgress` 先全檔驗證，損毀檔回 `ERR_PROGRESS_CORRUPTED` 且不呼叫保存；合併時 PracticeGroup/SrsState 依 updatedAt 較新覆寫、相等 skipped，Attempt 依 id 去重，contentHash mismatch 只移除該 Lesson 的 groups/srs/attempts。`ProgressRepository.saveProgressSnapshot` 只作交易 port，真 Drift adapter 留後續接線。
result: `packages/domain/test/progress_import_export_test.dart` 5/5 綠，涵蓋 export schema/無 key/audio/絕對路徑、AT-08-03、重複匯入冪等、AT-08-04、AT-08-07；`flutter test packages/domain/test` 70/70 綠，`flutter analyze` No issues，`git diff --check` 通過。hard-limits-matrix #13/#14/#26 已補 CT-06 證據；checker 仍只因 #9/#22 預期失敗。
reasoning: Domain snapshot 先行能把 M6 merge 規則變成可測純函式與 I/O 契約，又不替 #22 schema 做未授權決策；未來 Drift adapter 只需把 `saveProgressSnapshot` 實作為 transaction，即可沿用同一套全檔驗證與 merge policy。
recommendation: 後續接 infra adapter 時，務必讓所有 DB 寫入集中在 `ProgressRepository.saveProgressSnapshot` 的單一 transaction；不要在 UI 或 infra 重寫 updatedAt/contentHash merge 規則。若要加入 audit log，先依 task 8.4.2 向使用者確認 schema/持久化方案，不要把 audit 訊息塞進 `.aboprogress` 或 ProgressSnapshot。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
