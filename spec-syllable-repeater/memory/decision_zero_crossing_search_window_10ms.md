id: DEC-20260706-zero-crossing-search-window-10ms
type: decision
scope: project
source: syllable-repeater / fullstack-code-implementation S1b task 3.7
context: requirement §2.5 M1「原聲不可替換」允許的收尾處理＝零交越吸附 or ≤10ms micro-fade；AT-02-01「拖至 2440ms 放開→吸附最近零交越點後存回（2440±10ms 內）」。3.7 的搜尋窗設計需回應「±10ms」這個唯一具體數字。同時 S2 task 4.4 `renderStep` 端點收尾也走「≤10ms fade」，同一常數兩處使用。
action: 定 `const int kZeroCrossingSearchWindowMs = 10`（`packages/domain/lib/src/alignment/zero_crossing.dart`）作為對稱搜尋窗上限與 renderStep 端點 fade 的上限——兩處共用同一常數，M1 相關的「≤10ms」全在一個地方管。實作 `findNearestZeroCrossingMs(pcm, targetMs)`：以 `targetMs` 對應 sample 為錨點，`[anchor-441, anchor+441]` 掃描（441 = 10ms × 44100Hz / 1000），找到第一個相鄰 sample 變號或前為 0 的位置——距離錨點最近的贏；找不到回原 targetMs 不吸附。
result: 8 個測試涵蓋：金標準吸附／目標點本身即零交越／±10ms 外不吸附／邊界 clamp（sample index 0 與 pcm.durationMs）；`updateSyllableBoundary` 呼叫後 clamp 到開區間避免吸附推過鄰邊界的 corner case。與 M1 三同步（文件—程式—測試）齊備。
reasoning: 若 3.7 用另一個搜尋窗（例 20ms 或不吸附時採其他 fallback），與 M1「≤10ms fade」語意分岔——「加起來 ≤10ms」的直覺會被破壞。統一為 10ms 常數＝一次修就同步兩處，未來重評 M1 時只需回這一個常數。對稱搜尋而非「僅前向」是為了同時能吸附到光滑的過零點（如短音節收尾靠 zero-crossing 就無爆音）；「找不到就不吸附」讓 renderStep 收尾 fade 有機會補上，兩層防線互補。
recommendation: 若日後改 M1 允許窗（例：使用者反映吸附太保守），只改 `kZeroCrossingSearchWindowMs` 一個常數＋跑一次 domain test 就完成。不要在 renderStep 端另定第二個「fade 上限」常數；如需區分（例 fade≠window），也要在同檔集中管理。任何 fallback 加碼（例：找不到零交越時 alignmen 到 minimum-energy sample）**不得改變發音內容**（requirement §2.5 不可接受清單第 1 條），加碼前必須寫進 requirement.md 變動並跑核心驗收 CT-01。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
