id: WF-20260716-four-layer-export-recording-bounded-closeout
type: workflow
scope: project
source: syllable-repeater / S10 r6-r7 final closeout
context: 四層匯出允許切換原始音訊、排列、範圍與逐單元設定；錄音比較同時要求單次原音參考、UI 不阻塞與每圖最多 1000 點。若只在畫面過濾選項或只限制顯示點數，仍可能讓不相容資料進 renderer，或遺失波形首尾與極值。
action: 在 Domain 先建立 immutable PracticeExportPlan，以 fingerprint、lessonId、source range 三條件 fail closed；App 的排列候選依所選音訊來源即時過濾，export 只使用 plan snapshot。RecordingComparator 進 Isolate.run，圖點採保留首尾、內部分桶 min/max，且錄音參考由 renderer 忽略所有 repeat/silence，只取每個來源一次。
result: AT-21-04～07、AT-18-01～09 全綠；Domain 188/188、App 190/190；v1.1 guardrails #60/#61 轉 IMPLEMENTED。v3 pack 開啟時另解碼完整 original PCM，kept segment 可成為合法的原音範圍來源。
reasoning: 相容性屬資料契約，必須在 Domain 寫檔前再次驗證，不能只信 UI；限點需保留端點與局部極值，才能同時控制計算量並維持使用者看到的錄音輪廓。錄音與匯出都仍只走原始 PCM，避免破壞 M1/M10。
recommendation: 新增匯出來源時先擴充型別白名單與 planner 測試，不可用自由字串引入 Demucs／錄音；修改錄音圖演算法時固定用 480000 samples、首尾尖峰與中間尖峰三種 fixture 回歸。
confidence: high
status: active
verified_count: 1
created: 2026-07-16
last_used: 2026-07-16
