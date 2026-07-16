id: PF-20260706-record-plugin-lazy-init-indexedstack
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation S5 FP4 錄音比對
context: S5 新增 record 套件後，`AppShell` 使用 `IndexedStack` 同時 build 隱藏的 `PracticeScreen`。若 `PracticeController.build()` 立即 `ref.read(practiceRecorderProvider)`，widget/e2e test 會在沒有平台 plugin 時拋 `MissingPluginException`。2026-07-12 真 App smoke 又發現 macOS `record_macos` 的 `stop()` 可能在 WAV header/data 尚未完成收尾前回傳，若立即 decode 會出現看似錄到、實際無法比對或播放。
action: 將 `PracticeRecorder` 延遲到 `startRecording()` 才建立；controller 以 `_activeRecorder` 持有 instance。真機 stop 後以短輪詢等待 WAV 可完整 decode，逾時或 decode 失敗刪除來源檔；成功後將 PCM 暫存在目前步驟的記憶體，Domain compare 仍在 finally 刪來源檔，試聽只建立一次性 WAV 並於播放結束刪除。
result: 隱藏頁不再初始化平台 plugin；AT-06-06 測試覆蓋「先寫破損 bytes、稍後完成 WAV」並通過，另覆蓋等待失敗刪檔與播放暫存刪除。真 App 錄音流程具備可見的「播放錄音」入口，仍維持 M10 磁碟不保留錄音。
reasoning: 平台 plugin 的建構與 stop 都是平台生命週期邊界：建構可能立即觸發 method channel，stop 回傳也不代表容器檔已可安全讀取。把 plugin 延遲建立、把檔案就緒當成獨立 gate，才能讓 fake 測試與真機行為一致。
recommendation: 新增 just_audio、record、file_selector、secure storage 等平台 plugin 時，避免在 controller `build()` 或 hidden tab eager read；錄音 stop 後不要立即假設檔案完整，先以「存在＋可完整 decode」判定就緒，所有失敗路徑都要刪暫存。Riverpod `onDispose` 裡不要讀其他 provider，保存已建立 instance 做清理。
confidence: high
status: active
verified_count: 2
created: 2026-07-06
last_used: 2026-07-12
