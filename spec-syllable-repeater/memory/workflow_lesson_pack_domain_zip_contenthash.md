id: WF-20260706-lesson-pack-domain-zip-contenthash
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-1 LessonPackEngine 7.1
context: backend-design 將 `LessonPackEngine.write(Lesson, destPath)` 定義在 Domain，且 `Lesson` 欄位列出 pack 內 `audioRelPath`；但 `.abopack` 又必須包含原音 bytes、平台中立、無絕對路徑、無 key，若把 `audioRelPath` 解讀成本機檔案路徑，Domain 會被迫讀檔或保存絕對路徑，破壞 M5/REQ-09。
action: 將 `Lesson` 建成可攜聚合：`audioRelPath` 固定代表 pack 內相對路徑，原音資料放 `originalAudioBytes`，`LessonPackEngine` 只透過 `FileIo.writeBytesAtomic/readBytes` 寫入或讀出整個 `.abopack` 檔；pack 內用 `archive` 產生真正 zip，manifest 固定 `schemaVersion=1`，contentHash 以原音 bytes + syllables JSON 用 SHA-256 重算；read 時先全檔驗 manifest/schema/audio entry/contentHash，失敗一律 `ERR_PACK_CORRUPTED`，不部分載入。
result: `packages/domain/test/lesson_pack_engine_test.dart` 覆蓋 AT-07-01 round-trip 音訊位元級一致、AT-07-03 損毀 zip/缺音訊拒絕、AT-07-05 pack 無 key/secret/password 與無絕對路徑；`flutter test packages/domain/test` 54/54 綠，`flutter analyze` No issues。
reasoning: 把原音 bytes 放在 Lesson 內可讓 Domain 維持純 Dart 且不依賴桌面檔案路徑；pack entry 只保留相對路徑，未來手機/PWA 讀 pack 不需要重寫。contentHash 只吃「原音 bytes + syllables」也對齊 M6：文字譯文或 UI 設定變化不應誤觸 Lesson 內容重置。
recommendation: 後續 FP6 儲存/開啟 UI 應先由 infra/app 讀取使用者選定音檔 bytes，再組成 `Lesson(originalAudioBytes, audioRelPath: 'audio/original.wav')` 交給 `LessonPackEngine`；不要讓 Domain 用本機絕對路徑讀音檔，也不要把 API key、絕對路徑或授權/防盜欄位塞進 manifest。若擴充 vocals/instrumental/waveform/passive practice entries，仍要維持相對路徑與全檔驗證。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
