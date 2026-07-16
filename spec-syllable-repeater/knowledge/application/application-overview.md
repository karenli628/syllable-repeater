// AI-Generate
# application-overview

## 應用邊界

Syllable Repeater 是純本機、單人 macOS App。Flutter UI 負責工作流與互動，Domain 負責業務規則，Infra 負責 sidecar/DB/檔案/Keychain/HTTP adapter。專案沒有自家伺服器與 REST Controller；唯一遠端呼叫是使用者自帶 key 的 OpenAI Responses API 文字翻譯。v1.1 起邊界內新增：SegmentEngine（段落標籤）、Transcriber/Syllabifier 雙 Registry（語言路由）、CourseBundleEngine（`.abopack` v3）、ManagedTempSession（受管暫存）、audio_session 錄播協調；跨單元錄音暫存（RecordingBuffer）已於 v1.1-r7 明確移出邊界。

## 主要呼叫鏈

| 流程 | 入口 | 核心鏈路 | 主要產出 |
|------|------|----------|----------|
| 段落標籤 | `LabelingScreen` | `LabelingController` → `SegmentEngine.openAudio`（真實階段事件、雙 Registry 前置）→ whisper segment → `LabelSession` | 全軌波形、三態區段、`.abolabel` v2 |
| 匯入分析（單句） | `ImportScreen`（直接匯入或 pending Segment 交接） | `AudioImportReader` 逐 byte 就緒 → `AnalysisController` → `InfraAnalysisRunner` → `AnalysisPipeline`（雙 Registry 路由）→ FFmpeg/demucs/whisper/CMUdict | `AlignmentResult`、`AnalysisAudioTracks`（original/analysis 雙軌）、`DraftLessonIdentity` |
| 校正 | `EditorScreen` | `EditorController` → `AlignmentEngine.updateSyllableBoundary/removeBoundary/insertBoundary/updateSyllableText`；prosody 走 isolate runner | 更新後音節切點；總數變更→排列 markStale |
| 自由排列 | `ArrangementSection`（校正頁內） | `ArrangementController` → `PracticeArrangement` 聚合操作／`renderBlockRow` 列預覽 | immutable 排列快照、獨立 undo |
| 練習 | `PracticeScreen` | `PracticeController` → `PracticeEngine.effectiveUnits`（M12 唯一入口）→ `renderStep`/`renderBlockRow` | auto/custom 單元播放；四態顯示模式 |
| 匯出 | `ExportDialog` | `PracticeExportPlanner.build`（四層選擇）→ `PracticeEngine` 渲染 → FFmpeg mp3 | 單元/合併 mp3；來源指紋綁定 |
| 錄音比對 | `RecordPanel` | audio session coordinator → record adapter → `renderSinglePassReference`＋`RecordingComparator`（isolate、每圖 ≤1000 點） | 差異 overlay；目前單元記憶體 PCM 回放 |
| 課件/進度 | `LibraryScreen` / `ProgressSettingsScreen` | `LessonPackEngine`（v2）/`CourseBundleEngine`（v3）/ `ProgressEngine` / Drift repository | `.abopack`、`.aboprogress`（含 transcriptDisplayModes）、SRS 狀態 |
| AI 翻譯 | `ImportScreen` 譯文群組（v1.1 自設定頁搬入） | `AIService` → Keychain + OpenAI Responses | 可選 AI translation；manual 優先 |
| 發布 | release scripts | staging gate → Flutter release build → unsigned zip | x86_64 `.app` 與 `.zip.sha256` |

## 例外與降級

- sidecar timeout/crash/exit 非 0：回傳 DomainException，不拖垮 App。
- 段落頁 ASR 切段失敗：回正常空 session＋`ERR_TRANSCRIBE_FAILED` 警告，手動標記不受阻。
- demucs 缺件或失敗：降級使用原音。
- 語言查無切分器：`ERR_LANGUAGE_UNSUPPORTED` 附支援清單，禁默默 fallback 英文（M14）。
- `.abolabel`/`.abopack` 損毀或版本過高：全檔驗證零副作用，明確拒絕。
- dirty 標籤換音檔：Domain 攔截，UI 強制三選一。
- pitch 抽不到：`pitchAvailable=false`，其他韻律資料照常。
- AI provider 失敗：手動譯文仍可用，credential 不洩漏。
- 排列播放中資料變更：`_playRunId` 世代防護，舊快照停止淘汰。
- 多開 App：ManagedTempSession lease 鎖，不互刪暫存。
- release sidecar 缺件或授權不合：build/prepare/zip gate fail-closed。

## 真實進度與就緒語意（M15，v1.1）

所有匯入/解碼/分離/切段進度由真實 byte 或階段事件推進；可量測才顯示百分比，未知總量只顯示階段＋indeterminate。「音檔已就緒」必須代表位元組讀取、格式與時長驗證全部成功。UI 不得出現硬編假百分比。

## 發布型態

v1/v1.1 release 是 Intel x86_64、未簽章 macOS `.app`（ad-hoc 深層重簽、`codesign --verify --deep --strict` PASS）。Release build 走 bundled sidecar path，不能依賴開發機 `/usr/local/bin/ffmpeg`；v1.1 bundle 約 606MB（sidecar/模型 581MB）。使用者端安裝方式由 `release/README-unsigned-macos.md` 說明；v1.1 對外散布 zip 是否重打屬待確認。
