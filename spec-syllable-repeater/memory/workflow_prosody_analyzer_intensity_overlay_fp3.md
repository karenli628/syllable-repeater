id: WF-20260706-prosody-analyzer-intensity-overlay-fp3
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S4 ProsodyAnalyzer + FP3
context: REQ-05 重要邏輯列出 rhythm/intensity/停頓/stress/pitch，但 backend-design 介面 7 的 `Prosody` 欄位只定義 `rhythm[]/intensity[]/stress[]/pitchContour[]?/pitchAvailable`，沒有 pauseRegions。若為了「停頓偵測」臨時擴張欄位，會讓 domain model、UI、pack 介面偏離設計；若完全不測，又會讓 task 5.1 的停頓要求只停在文字。
action: 保持 `Prosody` 對外欄位不擴張：低能量停頓落在 `intensity[]` 曲線，並用 voiced→silence→voiced PCM 測試鎖住 silence windows 近 0。`ProsodyAnalyzer` 維持純 domain/只讀 PCM；AT-05-03 不放寬 `Syllable(endMs > startMs)` invariant，而以 sample index 換算後無有效樣本標 `NaN` 覆蓋 corrupted data。前端新增 `ProsodyOverlayControls`，`EditorController` 持有 `AsyncValue<Prosody>?`，analysis done / boundary dragEnd / undo 後同步重算；`WaveformCanvas` 只接收已計算的 `Prosody?` 並畫 pitch curve、stress markers、invalid/NaN 音節灰底。
result: `flutter analyze` No issues；`flutter test packages/domain/test` 46/46 ✅；`flutter test packages/infra/test` 55/55 ✅（2 sidecar skips）；`app/` 內 `flutter test` 35/35 ✅。`task-split.md` 5.1/5.2/FP3 已勾選；guardrails checker 仍因既有 5 條 REJECTED 預期失敗。
reasoning: S4 的核心不是新增更多輸出欄位，而是讓既有設計欄位可被穩定消費。`intensity[]` 是 RMS 曲線，本來就能表達低能量停頓；把 pause 當成該曲線的可視化/推導結果，比新增 `pauseRegions` 更不漂移。AT-05-03 也不應犧牲 `Syllable` invariant，否則會波及 boundary engine；用 sample-level invalid range 保留防腐敗語意即可。
recommendation: 後續若 S6 把 `Prosody` 寫入 `.abopack` 或手機端共用，沿用現有欄位；不要未經設計同步就加 `pauseRegions`。若 UI 要更明顯顯示停頓，可從 `intensity[]` 推導低能量區間放在前端 presentation 層，不要讓 domain 對外介面漂移。Widget/controller tests 應繼續透過 `prosodyAnalyzerProvider`/`EditorController.loadFrom(..., pcm:)` 注入，不要在 painter 裡做 DSP。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
