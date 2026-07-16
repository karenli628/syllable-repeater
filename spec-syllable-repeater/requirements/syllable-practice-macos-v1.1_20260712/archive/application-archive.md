// AI-Generate
# 應用層歸檔（Application Archive）

## 1. 歸檔資訊

| 欄位 | 內容 |
|------|------|
| 需求目錄 | `spec-syllable-repeater/requirements/syllable-practice-macos-v1.1_20260712/` |
| 歸檔時間 | 2026-07-16 11:00 |
| 對照/回寫知識庫 | `spec-syllable-repeater/knowledge/application/application-overview.md` |

## 2. 應用邊界與參與者（v1.1 增量）

- **使用者/角色**：不變——單人學習者/製作者。
- **系統邊界**：不變——Flutter macOS App＋純 Dart Domain＋Infra adapters；唯一遠端相依仍是使用者自帶 key 的 OpenAI Responses API。v1.1 新增邊界內元件：`SegmentEngine`（段落標籤）、雙 Registry（語言路由）、`CourseBundleEngine`（v3 封包）、`ManagedTempSession`（受管暫存）、`audio_session`（macOS 錄／播 session 協調）。
- **v1.1 明確移出邊界**：跨單元錄音暫存（RecordingBuffer）於 r7 撤回——錄音只在「目前單元、UI 記憶體、最近一次」存在。

## 3. 主業務流程（文字描述）

### 3.1 完整製課正常路徑（v1.1 全流程）

1. **段落標籤**：使用者在「段落標籤」頁匯入多句音檔。App 以真實 byte／階段事件顯示進度（指紋→解碼→可選分離→切段→波形），完成後顯示全軌波形與自動切段結果；ASR 失敗時仍開空 session＋警告，不阻斷手動標記。
2. 使用者拖曳標籤線、增刪邊界、標記保留／捨棄區間；可播放任一區段原音確認。未儲存改動換音檔時，Domain dirty 狀態機攔截並強制三選一（儲存／不儲存／取消）。
3. 標籤可匯出 `.abolabel`（v2）；同一音檔（SHA-256 指紋）再次開啟時，App 由 `label_registry` 索引提示載入既有標籤。
4. **單句分析**：使用者勾選一個區段「送到單句分析」（僅 metadata 交接，不複製 PCM），或直接匯入單句音檔。音檔逐 byte 讀取、格式與時長驗證全過才顯示「已就緒」；分析經雙 Registry 語言路由（查無切分器明確拒絕），完成後只顯示實際辨識音節。
5. **段落校正**：使用者增刪切點（±10ms 零交越吸附、50ms 下限）、雙擊 chip 改字；波形拖選時間範圍與文字積木雙向黃色高亮；音節總數變更即為 M2 步數新基準（M11），既有排列標 stale。
6. **自由排列**：一鍵生成 N 列句尾疊加，或手動組合積木（同列長按排序／成組／組內排序；來源段落點選插入）；雙擊積木／組塊設定 repeat（1–10）與 silence（0–20、0.5 級距）；列預覽播放共用 Domain 唯一渲染路徑。
7. **疊加練習**：練習頁依 `effectiveUnits` 顯示單元（0 列＝完整單句 1 單元；N 列＝N 單元即時連動）；四態字稿／譯文顯示（每 Lesson 記憶，隨 `.aboprogress`）；hidden 時全部脈絡只留編號。
8. **錄音**：錄一次只比對單元原音一次（單次參考，不含循環／靜音）；比對運算在 isolate、圖表限 1000 點；只保留目前單元最近一次記憶體 PCM 供回放確認，切單元／重錄／垃圾桶／離頁／關 App 即清；磁碟錄音與播放 temp 一律 finally 清除。
9. **封裝與匯出**：課程可整包存 `.abopack` v3（原始音訊必含；標籤／單句課件／排列／最新進度可選）；匯出走四層選擇（音訊來源→排列來源→單元範圍→設定覆寫），`PracticeExportPlan` 以 fingerprint/lessonId/range 拒絕不一致組合。

### 3.2 例外與回退（v1.1 增量）

| 場景 | 應用層行為 | 後端/Infra 規則 |
|------|------------|-----------------|
| 段落頁 ASR 切段失敗 | 顯示警告、開空 session，可手動標記 | `LabelOpenResult`＋`ERR_TRANSCRIBE_FAILED` warning；只有無法安全建 session 才拋例外 |
| `.abolabel` 損毀／指紋不符 | 就地錯誤提示，既有 session 不動 | 全檔驗證零副作用；`ERR_LABEL_CORRUPTED`／`ERR_LABEL_FINGERPRINT_MISMATCH` |
| dirty 換音檔 | 強制三選一，取消維持現狀 | Domain dirty 狀態機（#48） |
| 語言無切分器 | 明確拒絕建課件並列出支援語言 | Registry fail-closed `ERR_LANGUAGE_UNSUPPORTED`；無英文 fallback（M14） |
| 切點過近／低於 1 音節 | UI 就地拒絕提示 | `ERR_BOUNDARY_TOO_CLOSE`／`ERR_SYLLABLE_MIN_COUNT` |
| 積木設定越界 | 設定視窗拒絕 | `ERR_BLOCK_CONFIG_OUT_OF_RANGE`（1–10／0–20／0.5 級距） |
| 跨 Lesson 積木注入 | 不可能發生於 UI；Domain 雙層拒絕 | `ArgumentError` 含雙方 lessonId（#47） |
| 音節總數變更 | 排列標 stale banner，使用者明示重新生成或保留 | `markStale`；不自動重排（AT-15-08） |
| 排列播放中資料變更 | 舊快照播放被停止淘汰 | `_playRunId` 世代防護，不半新半舊 |
| 錄音 session 卡在 record 類別 | 播放前自動切換 | `PracticeAudioSessionCoordinator`：stop→釋放 record→啟用 playback |
| 多開 App 互刪暫存 | 各自持 lease，不誤刪對方 | `ManagedTempSession` lease 鎖＋白名單清掃 |
| v3 封包損毀／版本過高 | 明確拒絕，不錯讀 | 欄位白名單全驗證；未知版本 `ERR_PACK_CORRUPTED` |

## 4. 呼叫鏈與資料流（v1.1 新增鏈路）

### 4.1 前端 → 後端

| 步驟 | 前端動作（頁面/狀態） | 介面（語意） | 關鍵輸入 | 關鍵輸出 | 後續前端行為 |
|------|------------------------|--------------|----------|----------|--------------|
| 1 | 段落頁開音檔 | `SegmentEngine.openAudio`（介面 20） | path、separateVocals、onProgress | `LabelOpenResult`（session＋peaks＋warning?） | 真實階段進度→全軌波形 |
| 2 | 標籤線操作 | `LabelSession` 聚合（介面 21） | 邊界/三態/undo | 新 session 快照＋dirty | 重繪波形與清單 |
| 3 | 存/載標籤 | `LabelPackEngine`（介面 22/23） | session、destPath | `.abolabel` v2／載入 session | registry upsert、markSaved |
| 4 | 送單句分析 | `pendingSegmentProvider` 交接 | 原音路徑＋起訖＋text＋language | 單一槽位 metadata | ImportScreen 預填、來源徽章 |
| 5 | 匯入就緒 | `AudioImportReader`（介面 35） | path | byte 事件→ready | 就緒才開放「開始分析」 |
| 6 | 分析 | `AnalysisPipeline`（經雙 Registry） | ImportRequest（language、sourceRange?） | `AlignmentResult`＋`AnalysisAudioTracks` | 建 `DraftLessonIdentity`、跳校正 |
| 7 | 切點增減／改字 | `AlignmentEngine`（介面 24-26） | index、atMs、pcm、text | 新 AlignmentResult | 高亮／序號重排；排列 markStale |
| 8 | 排列操作 | `PracticeArrangement`（介面 27-28） | lessonId、rows/blocks/config | immutable 快照 | 列渲染／獨立 undo |
| 9 | 列預覽／練習播放 | `renderBlockRow`／`effectiveUnits`（介面 29-30） | row／lesson＋originalPcm | 渲染 PCM／`PracticeUnits` | PracticePlayer 播放 |
| 10 | 錄音比對 | `renderSinglePassReference`＋`compare`（介面 32-33） | 單元、錄音 PCM | 差異＋限點 overlay | 記憶體 PCM 回放；temp finally 清 |
| 11 | 顯示模式 | `SettingsService`（介面 34） | lessonId、mode | 持久化偏好 | 四態切換；隨 `.aboprogress` |
| 12 | v3 封包／四層匯出 | `CourseBundleEngine`／`PracticeExportPlanner`（介面 37-38） | bundle 選項／四層選擇 | `.abopack` v3／`PracticeExportPlan` | 匯出走 PracticeEngine 渲染 |

### 4.2 後端 → 資料 / 外部依賴（v1.1 增量）

| 步驟 | 後端邏輯單元 | 讀寫的表/檔案 | 外部系統 | 說明 |
|------|--------------|---------------|----------|------|
| 1 | `DriftLabelRegistryRepository` | `label_registry`（V3 新表） | SQLite/Drift | 指紋→標籤路徑索引；重匯入提醒 |
| 2 | `LabelPackEngine`＋`AtomicFileIo` | `.abolabel` v2 | local FS | temp→rename 原子寫入 |
| 3 | `DriftSettingsService` | `app_settings` | SQLite/Drift | 每 Lesson 顯示模式（adapter 層儲存；資料契約仍在 `.aboprogress`） |
| 4 | `DartIoAudioImportReader` | 音檔 bytes | local FS＋ffprobe | 逐 byte 讀取＋格式/時長驗證 |
| 5 | `WhisperAnalysisTranscriber.segment` | temp 16k WAV/JSON | whisper.cpp | v1.1 新增 segment 級時間戳能力 |
| 6 | `DemucsSeparator` | temp out dir | demucs.cpp | 改由原始檔直接準備 44.1kHz stereo |
| 7 | `ManagedTempSession` | 受管 temp 目錄（lease） | local FS | Whisper/Demucs 中介檔、練習快取、v3 解包的生命週期管理 |
| 8 | `PracticeAudioSessionCoordinator` | — | macOS audio session | 錄音／播放 category 切換 |

## 5. 非功能與執行約束（應用視角，v1.1 增量）

- **真實進度（M15）**：所有進度由真實 byte／階段事件推進；可量測才顯示百分比，未知總量只顯示階段＋indeterminate；「已就緒」必須代表非空＋格式＋時長全驗證。
- **效能**：切點增刪同步提交、prosody isolate 背景計算＋generation id 防倒灌；錄音比對 isolate＋每圖 ≤1000 點；Intel 10 秒音訊全管線 4.132s（上限 60s、回歸線 4.924s）。
- **並發防護**：匯入／分析各自 runId；排列播放 `_playRunId`；多開 App 靠 ManagedTempSession lease。
- **記憶體/磁碟衛生**：錄音最短生命週期（M10 r7）；sidecar 中介檔成功失敗皆清；v3 解包在切課／離頁／故障時清除；使用者保存的 pack/label/匯出檔有負向測試保護。
- **與知識庫約束對齊**：`backend-project.md` 已補 M11-M15；`backend-interface.md` 已補新 ports；`backend-database.md` 已補 label_registry。

## 6. Mermaid 序列圖（v1.1 主線）

```mermaid
sequenceDiagram
    participant U as 使用者
    participant L as 段落標籤頁
    participant SE as SegmentEngine
    participant I as 單句分析頁
    participant AP as AnalysisPipeline(雙Registry)
    participant E as 段落校正+自由排列
    participant P as 練習頁
    participant CB as CourseBundleEngine

    U->>L: 匯入多句音檔
    L->>SE: openAudio(真實階段事件)
    SE-->>L: LabelSession+波形(ASR失敗→空session+警告)
    U->>L: 標記保留/捨棄, 存 .abolabel v2
    U->>L: 勾選區段送單句分析
    L->>I: PendingSegment(metadata, 不複製PCM)
    I->>AP: analyze(language路由 fail-closed)
    AP-->>E: AlignmentResult+雙軌PCM+DraftLessonIdentity
    U->>E: 增刪切點/改字/自由排列
    E->>P: effectiveUnits(0列=1單元;N列=N單元)
    U->>P: 練習/錄音單次比對/顯示模式
    U->>CB: 整包存 .abopack v3 / 四層匯出
```

文字說明：v1.1 的應用主線是「段落標籤→單句分析→校正＋排列→練習→封裝匯出」五站式流程。三個關鍵不變式貫穿全鏈：①學習者聽到與匯出的每個 sample 都來自 originalPcm（分析軌只給 ASR）；②單元判定只有 `effectiveUnits` 一個入口；③錄音在任何路徑都不落持久化。

## 7. 開放問題（應用層）

| 編號 | 問題 | 影響範圍 |
|------|------|----------|
| A-101 | v1.1 對外散布用 unsigned zip 未重打（`dist/` 仍為 v1 產物） | 分發流程；`[需人工確認]` |
| A-102 | 舊版未管理 temp 298MB 待使用者批准一次性清理 | 本機磁碟 |
| A-103 | Apple Silicon/universal binary 仍為 Non-scope（沿 v1 A-002） | M 系列 Mac 使用者 |
