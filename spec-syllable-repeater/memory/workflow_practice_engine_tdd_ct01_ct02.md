id: WF-20260706-practice-engine-tdd-ct01-ct02
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S2 PracticeEngine
context: S2 要同時落地 M2/CT-02（buildSteps 11 步、第 2 步 `tion skills`）與 M1/CT-01（renderStep 輸出逐 sample 來自原 PCM sourceRanges，端點 ≤10ms fade 除外）。這兩條是本專案 PracticeEngine 的最高核心防線，交接檔要求不可跳過紅測試。
action: 先新增 `packages/domain/test/practice_build_steps_test.dart`，讓 `PracticeStep`/`PracticeEngine` 缺失造成 S2-1 red；再實作 `PracticeStep` model 與 `PracticeEngine.buildSteps` 轉綠。接著在同檔新增 renderStep CT-01 測試，讓缺 `renderStep` method 造成 S2-3 red；再實作 `renderStep`：逐段 copy `step.sourceRanges` 對應原 PCM sample、串接，端點用 `findNearestZeroCrossingMs`/`kZeroCrossingSearchWindowMs` 判斷，找不到精準 zero-crossing 時只做 ≤10ms 線性 fade。最後補 `singleSyllableStep` 供 4.7 editor chip 試聽。
result: `flutter test packages/domain/test` 39/39 ✅；CT-01/CT-02 已同步到 `hard-limits-matrix.md` #13/#14，`task-split.md` 4.1-4.4/4.7 勾選，`execution-log.md` 有紅測試與 green 記錄。
reasoning: 把 buildSteps 與 renderStep 分成兩輪 red→green，可以防止「先寫一包實作再補測」稀釋核心防線；renderStep 測試刻意比較「端點 fade 窗外的 sample」而不是整段全等，才能同時允許 M1 明定的 ≤10ms 收尾處理，又擋住生成/重算音訊路徑。buildSteps 只看 syllable，不看 word boundary，才能保證第 2 步是 `tion skills`。
recommendation: 後續改 PracticeEngine（尤其 S3 exportStep/exportMerged 或任何最佳化）時，先跑 `flutter test packages/domain/test`。若改 renderStep，必須保留「sourceRanges sample 來源比對」測試；不要把詞邊界或 wordIndex 帶進 buildSteps；不要用 TTS/合成/重採樣取代 copy 原 PCM。需要改 ≤10ms 規則時只改 `kZeroCrossingSearchWindowMs` 並同步更新 CT-01 測試。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
