id: WF-20260706-progress-import-export-domain-snapshot-m6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-4 ProgressEngine 7.4
context: 7.4 要做 `.aboprogress` 匯入/匯出，核心防線是 M6：updatedAt 較新覆寫、相等冪等、Lesson contentHash 變更只 reset 該 Lesson。2026-07-12 真 App smoke 發現需求與 backend design 明定 `.aboprogress`＝zip＋`progress.json`，但初版程式只把 JSON bytes 寫進自訂副檔名，造成格式契約漂移與使用者難以理解其用途。
action: Domain 保留 `ProgressSnapshot` / `MergeSummary` 與既有 merge policy，將 `exportProgress` 改為 ZIP 單 entry `progress.json`（內含 schemaVersion/exportedAt/progress）；`importProgress` 先解 ZIP 並完整驗證，再交易套用。為避免剛匯出的預發布純 JSON 檔失效，讀取端保留 legacy JSON 相容，所有新輸出一律正式 ZIP。
result: `packages/domain/test/progress_import_export_test.dart` 驗證 ZIP 只含 `progress.json`、schema/無 key/audio/絕對路徑、AT-08-03、冪等、AT-08-04、AT-08-07皆通過；UI 將 `.abopack` 儲存與 `.aboprogress` 備份集中在設定的檔案管理區，並維持兩種檔案彼此獨立。
reasoning: 自訂副檔名不等於封裝格式；格式必須由可驗證的容器結構決定。Domain snapshot 先行仍是正確分層，但輸出 adapter 也必須對齊設計的 ZIP 契約，否則跨平台交換與未來演進會失去依據。
recommendation: `.aboprogress` 新版本一律先更新 schema/entry 契約與 round-trip 測試，再改輸出；DB 寫入仍集中在 `ProgressRepository.saveProgressSnapshot` 單一 transaction，不在 UI/infra 重寫 M6。相容舊格式只能放在讀取端，輸出端不得繼續產生 legacy JSON。
confidence: high
status: active
verified_count: 2
created: 2026-07-06
last_used: 2026-07-12
