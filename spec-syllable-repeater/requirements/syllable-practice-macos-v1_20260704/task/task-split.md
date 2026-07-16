# Syllable Repeater macOS v1 — 任務拆分（task-split）

## 1. 本次任務拆分概覽

- **需求名稱**：語音/歌曲/台詞模仿練習系統（Syllable Repeater）macOS v1
- **依據的設計檔案**（拆分主依據）：
  - 後端：`../design/backend-design.md`（Domain Layer；介面 1–19、錯誤碼 §3.2.8、核心防線 §4.4）
  - 前端：`../design/frontend-design.md`（Flutter UI；功能點 1–8）
- **需求追溯**：`../requirement/requirement.md`（v1.1；REQ-01～09、AT-*、CT-01～10）
- **涉及範圍**：雙端（後端＝純 Dart Domain＋infra sidecar；前端＝Flutter macOS UI）
- **主要交付目標**：
  - macOS（Intel x86_64 優先）完整製作＋練習流程：匯入→對齊→校正→11 步疊加練習→匯出→比對→SRS
  - 金標準例句 `She has excellent communication skills`＝11 音節→10 切點→11 步全鏈路通過
  - M1–M10 核心防線三同步（文件＝程式＝測試）落地
- **時序總框架**：PLAN3.0 垂直切片 **S0→S1a→S1b→S1c→S2→S3→S4→S5→S6**，每片可獨立 demo；演算法模組（PracticeEngine／RecordingComparator）**先寫測試（TDD red→green→refactor）**。

**切片 ↔ 任務對照**：

| 切片 | Demo 標準（需求成稿 §5） | 涵蓋任務 |
|------|--------------------------|----------|
| S0 | sidecar 接線＋崩潰隔離 | 後端 1.*、2.* |
| S1a | 匯入金標準句→列 11 音節與時間戳 | 後端 3.1–3.5、8.1；前端 FP2 |
| S1b | 拖動 communication 內部邊界並存回 | 後端 3.6–3.7；前端 FP3 |
| S1c | 含背景音樂音檔分離 vocals | 後端 3.8 |
| S2 | 逐步播放 11 步，全為原聲 | 後端 4.1–4.4、8.2；前端 FP4（播放部分） |
| S3 | 匯出第 3 步 mp3＋合併靜音正確 | 後端 4.5–4.7；前端 FP5 |
| S4 | 波形＋音高曲線＋邊界線 | 後端 5.*；前端 FP3（疊圖） |
| S5 | 錄音 vs 原音切片疊圖標色 | 後端 6.*、8.3；前端 FP4（錄音比對） |
| S6 | 匯出課件含手動譯文路徑 | 後端 7.*；前端 FP6、FP1、FP7 |

---

## 2. 後端任務清單（Domain Layer＋infra，按模組/技術層次分區）

> 編號規則：`主分類.子任務`；完成後 `- [ ]`→`- [x]`。每條任務標注【風險分層｜Non-scope｜驗證方式】。
> 「涉及資料庫 schema」依規一律標 `[必須確認]`（本專案為新建本機 SQLite，無既有資料；核可本檔即視為確認 V1 schema，見開放問題 OQ-3）。

## 1. 儲存與資料模型（backend-design §3.1.2、§1.5）

- [x] 1.1 建立 Dart workspace 三包骨架 `packages/domain` / `packages/infra` / `app`，固化依賴方向（domain 零 flutter/sidecar 依賴）
  【`[可直接做]`｜Non-scope：不寫任何業務邏輯｜驗證：CT-05 前置——domain 包 `dart test` 可於無 Flutter 環境執行】
- [x] 1.2 實作 Drift schema V1（lesson_registry / practice_group / srs_state / attempt / app_settings 五表＋索引，等效 SQL 存 `packages/infra/lib/db/schema/V1__create_all.sql`）
  【`[必須確認]`（schema 規則）｜Non-scope：不建 V2 變更、不存任何音訊/key 欄位｜驗證：schema 對照 backend-design §3.1.2 逐欄核對；attempt 表結構斷言無音訊欄位（CT-10 結構防線）】
- [x] 1.3 實作 FileIO 抽象介面＋macOS 實作：temp→原子搬移寫入、App 啟動清空 `temp/`
  【`[可直接做]`｜Non-scope：不做雲端儲存｜驗證：AT-08-08（寫入中斷不留半成品）、AT-04-04】
- [x] 1.4 實作 Clock 抽象介面（M8 168h 判定與 SRS 排程之可測試時間源）
  【`[可直接做]`｜Non-scope：無｜驗證：CT-08 測試以假 Clock 驗 167h/169h】

## 2. Sidecar 基礎設施（backend-design §2.3-9、§3.2.1 依賴介面；S0）

- [x] 2.1 整備 x86_64 sidecar 二進位：FFmpeg（**LGPL build、動態連結**）、whisper.cpp、demucs.cpp，置於 `Contents/Resources/sidecar/`，附授權清單檔
  【`[需要回報]`（授權合規須回報核對）｜Non-scope：不編 Apple Silicon 版｜驗證：AT-09-05 / CT-09 授權掃描；FFmpeg 為 LGPL 動態連結】
  - **進度註記（2026-07-07）**：release sidecar staging gate 已落地但實體 bundle 尚未完成：新增 `SidecarPaths.bundled/current()`，Release AOT 走 `Contents/Resources/sidecar/`，Debug/Test 維持 `.local-tools/`；新增 `scripts/prepare_release_sidecars.py` 與 `scripts/test_prepare_release_sidecars.py`，staging 前跑 CT-09 license manifest gate，拒絕 `--enable-gpl` / `--enable-nonfree` 或非 shared FFmpeg；新增 macOS Release build phase `copy_release_sidecars.sh`，缺 `sidecar-manifest.json`、ffmpeg/ffprobe/whisper/demucs/model/cmudict 即中止 release build。本機 `/usr/local/bin/ffmpeg` 為 `--enable-gpl` dev-only，且 `.local-tools/demucs.cpp` 二進位/模型不存在，因此 2.1 不勾完成，等待 LGPL-only FFmpeg + demucs.cpp artifacts 後重跑 staging。2026-07-07 後續校正：sevagh/demucs.cpp 官方 CLI 為 `demucs.cpp.main <model-file> <wav> <out-dir>`，adapter/staging path 改用 `demucs.cpp.main` 與 `ggml-model-htdemucs-4s-f16.bin`。
  - **本輪補強（2026-07-07）**：新增 `scripts/fetch_sidecar_artifacts.py` 與 `scripts/test_fetch_sidecar_artifacts.py`，在 staging 前補 URL＋SHA-256＋授權三元組、HTTPS 憑證驗證、禁止 TLS/CERT 降級、禁止 GPL/AGPL 與 LGPL static artifact 的下載防線；`scripts/ci_core_checks.sh` 已納入測試。因來源 URL/SHA 尚待使用者確認且本機仍缺 release-safe FFmpeg/ffprobe 與 demucs.cpp.main/model，2.1 維持未勾選。
  - **完成註記（2026-07-07）**：已補齊 x86_64 release sidecar staging 實體工件並勾選 2.1。FFmpeg/ffprobe 由 FFmpeg 8.1.2 官方 source tarball（SHA-256 `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`）在無空白 build path 編譯，configure 含 `--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`，staged binary 以 `@executable_path/../lib` / `@rpath` 載入 shared dylib，並 bundle LGPL dynamic `libmp3lame.0.dylib`；demucs.cpp 由 `v0.0.4-alpha` commit `84e62f07ff77c5058a3493f7f9702cde606dae76` 本機 build，binary 為 x86_64 且只連系統 `Accelerate.framework`、`libc++`、`libSystem`；htdemucs 4-source 模型由 Hugging Face `Retrobear/demucs.cpp` 下載並驗 SHA-256 `72b17c42d308982ddb5069bc3bf48b81a5aac4cb6516e4366c0fa7cef6df0064`。已跑 `fetch_sidecar_artifacts.py --inventory-only`、`prepare_release_sidecars.py --dry-run`、`fetch_sidecar_artifacts.py --run-prepare` 成功，`app/macos/Runner/Resources/sidecar/` 產生本機 staging（實體 binaries/models 由 `.gitignore` 排除不進版控）。本機無 `gpg`，FFmpeg `.asc` 已保留但未做 PGP 驗章；本輪以 manifest SHA-256 pinning + CT-09 授權 gate + Mach-O 依賴檢查完成 release staging gate。
- [x] 2.2 實作 SidecarRunner（`Process.start` 包裝：逾時預設 120s 可設定、exit code 邊界、stdout/stderr 收集、殺行程回收）
  【`[可直接做]`｜Non-scope：不含各 sidecar 的參數組裝（歸模組 3/4）｜驗證：CT-04 / AT-01-04 故障注入（kill -9 → App 不崩、階段結果保留）】
- [x] 2.3 實作 FFmpeg 解碼契約（→16-bit/44.1kHz/mono PCM＋時長）與格式/長度前置驗證（mp3/wav/m4a/flac、≤10 分鐘）
  【`[可直接做]`｜Non-scope：不做轉檔匯出（歸 4.6）｜驗證：AT-01-03（0 byte 檔明確報錯）；Q8 格式邊界】

## 3. 對齊模組 AnalysisPipeline／AlignmentEngine（介面 1、2；S1a/S1b/S1c）

- [x] 3.1 實作 CMUdict 載入與單字音節數查詢＋母音團計數 fallback（查無字強制 needsReview）
  【`[可直接做]`｜Non-scope：不支援非英文完整切分（Non-scope 8）｜驗證：AT-01-07（blorptastic fallback）】
- [x] 3.2 實作 whisper.cpp 轉寫/對齊契約（詞級時間戳 JSON 解析；有字稿對齊、無字稿轉寫草稿）
  【`[需要回報]`（模型檔選擇影響體積與效能，OQ-1）｜Non-scope：不含 MFA 外掛｜驗證：AT-01-01/02 金標準句詞邊界】
- [x] 3.3 實作音節切分演算法：單音節字直取 whisper 邊界；多音節字等比例切＋needsReview；組裝 AlignmentResult
  【`[可直接做]`｜Non-scope：不做音素級對齊｜驗證：**AT-01-01（金標準句恰 11 Syllable）**；AT-01-06（區間單調遞增互不重疊）】
- [x] 3.4 實作 AnalysisPipeline 編排（解碼→可選分離→辨識→切分；`Stream<AnalysisEvent>` 階段化進度；重入鎖）
  【`[可直接做]`｜Non-scope：不含 UI 進度顯示｜驗證：AT-01-04/05；介面 1 欄位表逐欄核對】
- [x] 3.5 產出 waveform peaks 計算（供前端 CustomPainter 快取）
  【`[可直接做]`｜Non-scope：不做多解析度縮放版本｜驗證：編輯器渲染 ≥30fps 之資料前提（REQ-02 3.2.6）】
- [x] 3.6 實作 `updateSyllableBoundary`（開區間驗證＋`ERR_BOUNDARY_INVALID`；介面 2）
  【`[可直接做]`｜Non-scope：undo 堆疊歸前端｜驗證：AT-02-02/05（越界拒絕、閉端拒絕）；`packages/domain/test/alignment_boundary_test.dart` 7/7 全綠】
- [x] 3.7 實作零交越吸附（回傳 snappedMs；亦供 renderStep 收尾複用）
  【`[可直接做]`｜Non-scope：不改變發音內容（§0.1 收尾限定）｜驗證：AT-02-01（吸附落點 ±10ms 內、接點無爆音）；`packages/domain/lib/src/alignment/zero_crossing.dart` `findNearestZeroCrossingMs`，對稱窗常數 `kZeroCrossingSearchWindowMs=10`（供 4.4 renderStep 收尾共用）】
- [x] 3.8 實作 demucs.cpp 分離契約接入（失敗可跳過降級用原音；S1c）
  【`[需要回報]`（移植版選定，OQ-2）｜Non-scope：不內建進 domain（走 SidecarRunner）｜驗證：S1c demo——含背景音樂檔分離後邊界仍正確】
  【**OQ-2 定案（2026-07-06）**：sevagh/demucs.cpp（MIT License, Copyright 2023 Sevag H；主依賴 Eigen MPL-2.0）通過 M9 授權白名單；使用者透過 hard-guardrails skill 的 WebFetch 核對 LICENSE 檔實際內容】
  【**產物**：`packages/infra/lib/src/sidecar/demucs_separator.dart` (`DemucsCppVocalSeparator implements AnalysisVocalSeparator`) ＋`test/demucs_separator_test.dart` 7 情境（含錯誤映射 + 成功路徑）＋`test/demucs_integration_test.dart` @Tags(['sidecar'])（skip if missing）＋app 端 `demucsReadyProvider` + UI 未就緒 tooltip 提示 3 情境測試】
  【**依賴注入**：`app/lib/shared/infra/infra_analysis_runner.dart` 依 `paths.demucsAvailable()` 條件性注入 `vocalSeparator`；未就緒時 pipeline 走 `if (vocalSeparator != null)` null 分支自動降級（backend-design §5 第 704 行、M4）】
  【**使用者本機事宜**（本輪 Non-scope）：demucs.cpp 二進位 build 與 htdemucs 模型下載——待使用者本機準備後真整合測試自動變綠。2026-07-07 已依 sevagh/demucs.cpp README 校正 CLI 為 `demucs.cpp.main <model-file> <input> <out-dir>`，vocals 輸出讀 `target_3_vocals.wav`】

## 4. PracticeEngine（介面 3–6；S2/S3；★TDD 先寫測試）

- [x] 4.1 【TDD-red】先寫 buildSteps 測試：金標準句 11 音節→**11 步**、第 2 步＝`tion skills`（不吸附）、5 音節句→5 步、repeatN 0/11 拒絕
  【`[可直接做]`｜Non-scope：不寫實作｜驗證：CT-02、AT-03-01/03/07/04（測試先紅）】
- [x] 4.2 實作 buildSteps（純函式：句尾倒數疊加、sourceRanges 僅存 TimeRange、totalDurationMs＝片段長×repeatN）
  【`[可直接做]`｜Non-scope：不做單字邊界吸附（不可接受清單）｜驗證：4.1 測試轉綠】
- [x] 4.3 【TDD-red】先寫 renderStep §0.1 回歸測試：輸出與原 PCM 對應區間**逐 sample 相等**（端點 ≤10ms fade 除外）
  【`[可直接做]`｜Non-scope：無｜驗證：**CT-01、AT-03-02**（本專案最高防線測試）】
- [x] 4.4 實作 renderStep（唯一路徑：copy sourceRanges→串接→零交越/micro-fade 收尾；複用 3.7）
  【`[可直接做]`｜Non-scope：**禁止任何生成/合成路徑（M1）**｜驗證：4.3 測試轉綠＋CI 常駐】
- [x] 4.5 【TDD-red】先寫匯出靜音規則測試：`thank you very much` N=3→靜音 1.2s/1.8s…（解碼實測 ±20ms）；單步合併無尾端靜音
  【`[可直接做]`｜Non-scope：無｜驗證：CT-03、AT-04-02/03/06】
- [x] 4.6 實作 exportStep／exportMerged（sample 數插靜音、FFmpeg mp3 編碼、temp→原子搬移、回傳 silenceGapsMs、重入鎖）
  【`[可直接做]`｜Non-scope：不做 mp3 以外格式（允許變動，留擴充）｜驗證：4.5 測試轉綠；AT-04-01/04/05】
- [x] 4.7 單音節試聽支援（單音節 PracticeStep 建構輔助，供前端編輯器試聽走 renderStep）
  【`[可直接做]`｜Non-scope：無｜驗證：試聽輸出同樣通過逐 sample 斷言（M1 貫穿）】

## 5. ProsodyAnalyzer（介面 7；S4）

- [x] 5.1 實作 rhythm（音節時長比例）＋intensity（RMS 曲線）＋停頓偵測＋stress（能量×時長加權）
  【`[可直接做]`｜Non-scope：只讀不寫音訊（§0.1）｜驗證：AT-05-01（11 個比例值）、AT-05-04（原檔 hash 不變）】
  - **進度註記（2026-07-06）**：`ProsodyAnalyzer.analyze` 已輸出 rhythm/intensity/stress；停頓偵測依 backend-design 介面 7 不擴張欄位，落在 `intensity[]` 低能量窗並以測試鎖住。AT-05-04 以 PCM sample 前後不變驗證只讀。
- [x] 5.2 實作 YIN pitch 抽取＋降級（抽不到→pitchAvailable=false，其餘照常；演算法封裝可換 WORLD）
  【`[可直接做]`｜Non-scope：不實作 WORLD（v1.5）、不做 CREPE｜驗證：AT-05-02（耳語降級不失敗）、AT-05-03（0 長度音節跳過）】
  - **進度註記（2026-07-06）**：已以 autocorrelation style pitch extraction 封裝於 `ProsodyAnalyzer` 內；零 PCM/氣音類情境降級為 `pitchAvailable=false`、`pitchContour=null`，rhythm/intensity/stress 照常。`Syllable` domain model 仍維持 `endMs > startMs` invariant，AT-05-03 以 sample index 換算後無有效樣本標 NaN 覆蓋 corrupted data 落點。

## 6. RecordingComparator（介面 8；S5；★TDD 先寫測試）

- [x] 6.1 【TDD-red】先寫比對測試：依 step 時間戳從整句原音切出正確基準片段；錄音 <0.2s 拒絕；**finally 刪錄音檔斷言**
  【`[可直接做]`｜Non-scope：無｜驗證：CT-10（刪檔）、AT-06-02】
  - **進度註記（2026-07-06）**：已新增 `RecordingAudioSource` domain port、`ComparisonResult/OverlayData` 與 `RecordingComparator.compare`；錄音 <200ms 回 `ERR_RECORDING_TOO_SHORT`，decode 失敗也會進 `finally`，兩者皆斷言呼叫 `delete(userRecordingPath)`。Domain 不 import `dart:io`，刪檔副作用透過 port 交 infra 實作。
- [x] 6.2 實作 DTW 對齊＋rhythmDelta/intonationDelta/overlayData（差異區段 TimeRange 列表）
  【`[可直接做]`｜Non-scope：不存任何錄音（M10）；score 為可選不強求｜驗證：6.1 測試轉綠；AT-06-01（10 秒錄音 ≤2s 出圖之效能斷言）】
  - **進度註記（2026-07-06）**：`RecordingComparator` 以 RMS curve / pitch contour 做降採樣 DTW，產出 `rhythmDelta`、`intonationDelta`、雙波形/音高 overlay 與 `diffRanges`；10 秒錄音測試於 2 秒內完成。Infra `FileRecordingAudioSource` 支援 PCM 16-bit mono WAV decode，格式錯誤映射 `ERR_DECODE_FAILED`，delete 轉交 `FileIo`。

## 7. LessonPackEngine＋AIService＋ProgressEngine（介面 9–19；S6）

- [x] 7.1 實作 `.abopack` write/read（zip+JSON、schemaVersion=1、contentHash 重算、全檔驗證不部分載入、無絕對路徑/無 key）
  【`[可直接做]`｜Non-scope：不做授權/防盜欄位（Non-scope 4）｜驗證：AT-07-01（round-trip 位元級等價）、AT-07-03、AT-07-05（pack 無 key）】
  - **進度註記（2026-07-06）**：已新增 `Lesson` / `Translation` / `PracticeConfig` 與 `LessonPackEngine`，使用純 Dart `archive` 寫 zip、`crypto` 算原音 bytes + syllables 的 contentHash。`write` 先重算 contentHash 並以 `FileIo.writeBytesAtomic` 寫入；pack 僅含 `manifest.json` 與 `audio/original.wav` 等相對路徑；`read` 先驗 `schemaVersion=1`、manifest、音訊 entry 與 contentHash，不合格一律 `ERR_PACK_CORRUPTED`，不部分載入。測試覆蓋 AT-07-01/03/05；`flutter test packages/domain/test` 54/54 綠，`flutter analyze` No issues。
- [x] 7.2 實作 AIService（SecureStore 介面走 Keychain、translate、manual 優先覆蓋規則、失敗不阻斷）
  【`[需要回報]`（外部服務商契約與 key 安全路徑須回報核對）｜Non-scope：**不得觸碰音訊（§0.1）**；不做金流｜驗證：AT-07-02/04/06、CT-10（key 不落地掃描）】
  - **進度註記（2026-07-06）**：已完成 Domain 可測部分：新增 `SecureStore` / `AiClient` ports、`AiProviderConfig` / `AiRateLimit` / request-response value types 與 `AIService.configure/translate/mergeTranslation`；未設 key 回 `ERR_AI_KEY_MISSING`、client 失敗包成 `ERR_AI_CALL_FAILED`、manual translation 永遠勝出。`AIService` 僅處理文字、不 import `http` / Flutter / `dart:io`，真 Keychain adapter 與真 provider HTTP adapter 仍待外部服務商契約與 key 安全路徑回報核對後再接。
  - **完成註記（2026-07-08）**：真 Keychain / provider HTTP adapter 已接線並勾選 7.2。新增 `app/lib/shared/infra/keychain_secure_store.dart` 以 `flutter_secure_storage` 實作 macOS Keychain `SecureStore`，失敗轉 `ERR_AI_CALL_FAILED` 且錯誤訊息不含 credential；新增 `app/lib/shared/infra/openai_responses_client.dart` 實作 OpenAI Responses API client，request body 只含文字 `targetLang/text`，credential 僅進 Authorization header，provider 失敗不洩 key。`app/lib/features/progress/ai_settings_service.dart` 已移除 `InMemoryAiSecureStore` / `NoopAiClient`，正式 provider 改為 `KeychainSecureStore` + `OpenAiResponsesClient`，預設 `https://api.openai.com/v1/responses` / `gpt-5.4-mini`（依 OpenAI 官方 Models 頁：低延遲/低成本選 mini 族系；Responses API 支援文字輸入與文字輸出）。`app/test/shared/ai_adapters_test.dart` 覆蓋 Keychain wrapper、Responses output_text/output.content[].text、provider failure 不洩 credential、provider 預設接線；`progress_ui_test.dart` 仍覆蓋 AI key UI 送出即清空。未啟用尚未設計完的自動翻譯 UI source 流，避免把 AI 結果誤存成 manual；手動譯文路徑維持永遠可用。
- [x] 7.3 實作 ProgressEngine 結算與 SRS（settle：間隔序列 [0,1,3,7,14,30]＋難度三檔；dueList：HARD 優先、無逾期概念）
  【`[可直接做]`｜Non-scope：schema 上不建任何失敗/逾期欄位（M7 結構防線）｜驗證：AT-08-01、CT-07/AT-08-02】
  - **進度註記（2026-07-06）**：已新增 `ProgressEngine.settle/dueList`、`ProgressRepository` port、`PracticeGroup` / `SrsState` / `DueGroup` / `Attempt` 等 Domain 型別；`packages/domain/test/progress_engine_test.dart` 覆蓋 AT-08-01、AT-08-02/CT-07 與 HARD priority。`dueList` 只查詢不寫狀態，跨日未練不記失敗/懲罰。
- [x] 7.4 實作進度匯入匯出（exportProgress／importProgress：全檔驗證→交易套用、updatedAt upsert、contentHash 只重置該 Lesson、MergeSummary）
  【`[可直接做]`｜Non-scope：不做雲端同步（Non-scope 5）｜驗證：CT-06、AT-08-03/04/07】
  - **進度註記（2026-07-06）**：Domain 可測部分完成：新增 `ProgressSnapshot` / `MergeSummary`，`ProgressEngine.exportProgress/importProgress` 以 schemaVersion=1 JSON `.aboprogress` 透過 `FileIo` 原子寫入/讀取，先全檔驗證再合併，損毀檔回 `ERR_PROGRESS_CORRUPTED` 且不呼叫保存；`updatedAt` 較新覆寫、相等冪等、contentHash 變更只 reset 該 Lesson。`ProgressRepository.saveProgressSnapshot` 已明定 infra adapter 必須交易套用；真 Drift adapter / FP7 MergeSummary UI 尚待後續接線。
  - **接續註記（2026-07-06）**：真 Drift adapter 已完成：`DriftProgressRepository.saveProgressSnapshot` 以 transaction 清舊表後套用 snapshot，保留既有 `lesson_registry.pack_path/title`，`packages/infra/test/drift_progress_repository_test.dart` 覆蓋交易保存；FP7 已接 `ProgressSettingsScreen` 的 `.aboprogress` file picker 與 MergeSummary 對話框，`app/test/progress/progress_ui_test.dart` 覆蓋匯出/匯入 UI。
- [x] 7.5 實作歸檔狀態機（ACTIVE→ARCHIVED→ACTIVE(<168h)/EXPIRED(≥168h 不可逆)；Clock 注入）
  【`[可直接做]`｜Non-scope：無｜驗證：CT-08、AT-08-05/06（167h/169h 兩側）】
  - **進度註記（2026-07-06）**：Domain 可測部分完成：新增 `ProgressEngine.archive/restore` 與 `ProgressRepository.saveGroup` port。`archive` 只允許 ACTIVE→ARCHIVED 並寫 `archivedAt=clock.now()`；`restore` 以注入 Clock 判定 168h（不含），167h 內回 ACTIVE 並清 `archivedAt`，169h 後惰性轉 EXPIRED 並拋 `ERR_ARCHIVE_RESTORE_EXPIRED`；ARCHIVED/EXPIRED 不進 `dueList` 且 `dueList` 不寫狀態。真 Drift adapter / 操作紀錄仍待後續接線。
  - **接續註記（2026-07-06）**：真 Drift adapter 與 #22 操作紀錄已完成：`saveGroup/findGroup` 保存 `status/archived_at`，`archive/restore/restore expired` 寫 `audit_log`；`packages/domain/test/progress_archive_test.dart` 與 `packages/infra/test/drift_progress_repository_test.dart` 覆蓋 CT-08 與持久化。FP7 已補 `LibraryScreen` 歸檔確認、`ProgressSettingsScreen` ARCHIVED 168h 倒數、恢復入口與 EXPIRED disabled 狀態；`app/test/progress/progress_ui_test.dart` 覆蓋 UI。
- [x] 7.6 實作 reminderConfig 三參數讀寫（預設 15/5/2，存 app_settings 非硬編碼）
  【`[可直接做]`｜Non-scope：不做系統通知推播（v1 App 內提醒）｜驗證：Q9 定案值檢視＋設定往返】
  - **進度註記（2026-07-06）**：`ReminderConfig.defaults = 15/5/2` 已於 Domain 落地；`ProgressEngine.reminderConfig/setReminderConfig` 透過 `ProgressRepository.loadReminderConfig/saveReminderConfig` 讀寫，Drift adapter 存 `app_settings` 三鍵 `reminder.minutes` / `reminder.failCap` / `reminder.dailySessions`，保存時寫 `audit_log`。`app/lib/features/progress/progress_settings_screen.dart` 提供可測設定 UI；`packages/domain/test/progress_settings_test.dart`、`packages/infra/test/drift_progress_repository_test.dart`、`app/test/progress/progress_ui_test.dart` 綠。

## 8. 測試與 CI（跨模組；三同步之「測試」端）

- [x] 8.1 建立 CI-ready 防線：domain 包於**無 Flutter 容器**跑 `dart test`＋依賴白名單檢查（禁 flutter/sidecar import）
  【`[可直接做]`｜Non-scope：不建立 GitHub Actions / 遠端 CI（待 git repo 決策後再接）｜驗證：CT-05、AT-09-01/02；落點：`packages/domain/test/domain_purity_test.dart`】
- [x] 8.2 集成核心驗收總表測試套件（CT-01～CT-10 逐條對應之自動化測試常駐 CI；CT-09 授權掃描腳本）
  【`[可直接做]`｜Non-scope：CT-09 之人工簽核流程另列發版 checklist｜驗證：CI 綠＝2.5「必須維持」全數有測試（憲法 C10 三同步）】
  - **進度註記（2026-07-06）**：CT-09 本機授權 gate 已落地：新增 `scripts/check_licenses.py`、`scripts/test_check_licenses.py`、`release/license-manifest.json` 與 `release/release-checklist.md`。腳本掃 release manifest，擋 GPL/AGPL/CC BY-NC/non-commercial/research-only、擋 bundled Python runtime，並要求 LGPL bundled 元件必須 dynamic linking；unittest 覆蓋 GPL/GPL-3.0 注入、LGPL static linking、bundled Python 與空 manifest。當時 8.2 整體尚未勾選完成，因 CT-01～CT-10 常駐遠端 CI 尚待 GitHub repo/branch protection 最後 gate。
  - **接續註記（2026-07-07）**：GitHub Actions 常駐 gate 已落地：`.github/workflows/ci.yml` 於 push/PR 跑 `scripts/ci_core_checks.sh`，涵蓋 guardrails checker、CT-09 license gate、license unittest、domain/infra/app 測試與 `flutter analyze`。遠端 run `28808859106`（commit `62a0695`）在 `macos-15` + Flutter `3.44.4` 通過。
- [x] 8.3 效能基準測試：10 秒音檔對齊管線於 i5-8259U 實測，回填 Q10 目標數值
  【`[需要回報]`（實測結果決定是否調整 60s 目標）｜Non-scope：不換演算法（Q10 定案）｜驗證：REQ-01 3.2.6 效能列】
  - **進度註記（2026-07-07）**：新增 `packages/infra/bin/benchmark_alignment_pipeline.dart`，以使用者提供 mp3 產生 10,000ms benchmark WAV 後量測完整 `AnalysisPipeline`（FFmpeg decode → whisper.cpp small.en `--no-gpu` → CMUdict syllabify → waveform peaks）。基準機 `Intel(R) Core(TM) i5-8259U CPU @ 2.30GHz` 實測 `elapsedMs=4689`（4.689s）、`syllableCount=22`、`waveformPeaks=32`，Q10 目標鎖定為 10 秒音檔 ≤ 60 秒且本次通過。

### 8.4 硬性限制實作（2026-07-05 hard-guardrails skill 使用者裁決 REJECTED 之 5 條）

> 來源：`guardrails/hard-limits-matrix.md` 5 條原始 REJECTED_NEEDS_IMPLEMENTATION 對應。2026-07-07 #9 已落地，matrix 已無 `REJECTED_NEEDS_IMPLEMENTATION`；後續仍由 `check_guardrails.py` 擋住任何新增未落地項。

- [x] 8.4.1 Branch Protection（matrix #9）：GitHub 端設 main branch protection 阻止 force push；`.githooks/pre-push` 加最小檢查（本機 test 未過不 push）
  【`[需要回報]`（GitHub repo 建立時機由使用者拍板）｜Non-scope：不引入 CI 平台自動 merge check（單人 repo 無 PR）｜驗證：GitHub UI 顯示分支保護規則啟用；本機嘗試 `git push -f main` 失敗】
  - **進度註記（2026-07-07）**：GitHub repository 已建立為 `https://github.com/karenli628/syllable-repeater`。private repository 建立 ruleset 時 GitHub API 回 403（private rulesets 需 GitHub Pro），使用者明確授權改 public 後，已建立 Repository Ruleset `main branch protection`（id `18580116`）：`enforcement=active`、`target=branch`、include `refs/heads/main`、rules `deletion` + `non_fast_forward`。依使用者限制未執行 `git push --force` 測試。
- [x] 8.4.2 Audit Log（matrix #22）：settings/SRS 關鍵設定變更寫入輕量 audit_log（新表 or app_settings 內欄位或本機檔案）；歸類為單人本機自審用途，非稽核級不需 immutable
  【`[必須確認]`（涉及 schema 或設定持久化，見 backend-design §3.1.2）｜Non-scope：不做 tamper-proof / append-only；不記錄練習軌跡（已有 attempt 表）｜驗證：改 reminderConfig / AI key 後 audit_log 有一筆；DB schema 檢查 audit_log 表存在（若走表方案）】
  - **進度註記（2026-07-06）**：使用者已確認採 Drift `audit_log` 表。V2 schema 已新增 `audit_log(id, occurred_at, actor, action, target_type, target_id, metadata_json)` 與 time/action 索引；Domain 新增 `AuditLogEntry` / `AuditLogSink`，敏感 token（key/secret/password/credential/audio/recording/path）拒絕；`ProgressEngine.archive/restore/setReminderConfig` 與 `AIService.configure` 寫入 audit sink。`hard-limits-matrix.md` #22 由 `REJECTED_NEEDS_IMPLEMENTATION` 轉 `PARTIAL`，原因是真 Keychain/provider adapter 與完整 FP7 設定 UI 尚待接線驗證。
- [x] 8.4.3 Rate Limit（matrix #23）：AIService.translate 前加內部 rate limiter（例：每分鐘 N 次上限，觸發時就地錯誤`ERR_AI_CALL_FAILED` 加 rate-limit reason），防手滑狂點耗費
  【`[可直接做]`｜Non-scope：不做全局 quota（見 DL-011 APPROVED）｜驗證：連續呼叫 N+1 次第 N+1 次立刻返回 rate-limit 錯誤；不呼叫外部 API】
  - **進度註記（2026-07-06）**：`packages/domain/lib/src/ai/ai_service.dart` 於 client 呼叫前維護 window 內呼叫時間；超過 `AiRateLimit.maxRequests` 回 `ERR_AI_CALL_FAILED（rate-limit）`，`packages/domain/test/ai_service_test.dart` 驗證第 N+1 次不呼叫 fake client。
- [x] 8.4.4 Network Policy（matrix #31）：AIService 呼叫前檢查目標 URL host 在 hardcode allowlist（AI 服務商官方 domain，如 `api.openai.com`、`api.anthropic.com`），host 不在清單則就地拒絕 `ERR_AI_CALL_FAILED`
  【`[可直接做]`｜Non-scope：不做全流量 packet inspection；不接管 OS 網路設定｜驗證：測試改 config 指向 `evil.example.com` → 呼叫返回 host-blocked 錯誤，不發實際請求】
  - **進度註記（2026-07-06）**：`AIService` 僅允許 `https` 且 host 在 `api.openai.com` / `api.anthropic.com` allowlist；`evil.example.com` 測試回 `ERR_AI_CALL_FAILED（host-blocked）` 且 fake client calls 為空。
- [x] 8.4.5 Prompt Injection Guard（matrix #34）：AIService.translate 前加 sanitizer（strip 明顯 injection 樣式：`ignore previous instructions`、`system:`、`</s>` 等控制標記；標註可疑輸入讓使用者確認），為「未來拿線上歌詞當字稿」情境預備防線
  【`[可直接做]`｜Non-scope：不做完整 LLM guardrail 服務（如 NeMo Guardrails）｜驗證：注入樣本測試——含 `ignore previous instructions...` 之字稿觸發 sanitizer；乾淨字稿不受影響】
  - **進度註記（2026-07-06）**：`AIService` 在 client 呼叫前 fail-closed 拒絕 `ignore previous instructions`、`system:`、`developer:`、`</s>`、`<|system|>` 等控制標記；測試驗證可疑字稿不呼叫 fake client。因目前尚無 UI confirmation flow，Domain 層採保守拒絕並回 `ERR_AI_CALL_FAILED（prompt-injection-review-required）`。

## 9. 建置與發布（macOS）

- [x] 9.1 macOS release build（x86_64）＋LGPL 動態連結核對＋授權告知文件隨附
  【`[需要回報]`｜Non-scope：不做 Apple Silicon/universal binary、不做 Windows｜驗證：AT-09-05】
  【**M9 前置（2026-07-05 使用者拍板）**：`app/macos/Runner/DebugProfile.entitlements` 與 `Release.entitlements` 內 `com.apple.security.app-sandbox: true` 必須改為 `false`，否則 sandbox 會擋 `.local-tools/` 讀取與 `/usr/local/bin/ffmpeg` spawn，App 本體 UI 起不來（S1a e2e demo 已用 widget test `tester.runAsync` 覆蓋，App 本體 UI demo waived 到本任務）。詳 memory `decision_macos_sandbox_ui_demo_waived_v1`。**不要**加 `temporary-exception.files.absolute-path.*`——那只在簽章 App 生效，本專案免簽章路線下無效】
  - **進度註記（2026-07-08）**：M9 前置已落地：`DebugProfile.entitlements` / `Release.entitlements` 皆改為 `com.apple.security.app-sandbox: false`，未加入 temporary exception；`fetch_sidecar_artifacts.py --inventory-only` ✅、`prepare_release_sidecars.py --dry-run` ✅、staging manifest/bin/lib/models/data 皆存在；`otool -L` 核對 staged FFmpeg 使用 `@rpath` shared dylib 與 dynamic `libmp3lame.0.dylib`，demucs.cpp.main 只連系統 `Accelerate.framework`、`libc++`、`libSystem`。`flutter build macos --release` 實跑被 Codex escalation 用量限制拒絕，非程式碼錯誤；不得繞路重試同等權限 build，9.1 維持未勾選。
  - **完成註記（2026-07-11）**：已完成 x86_64 Release build。首次乾淨重建時 `gen_snapshot_x64` 0% CPU / 40K footprint 卡住；確認 `gen_snapshot_x64 --version` 也會卡住，根因為 Flutter SDK `gen_snapshot_x64` 帶 `com.apple.quarantine`（Homebrew Cask）。移除該 quarantine 後 `flutter build macos --release --no-pub` 成功，產出 `app/build/macos/Build/Products/Release/syllable_repeater_app.app`（634MB），主執行檔 `file` = Mach-O x86_64。bundle 內 `Contents/Resources/sidecar/` 含 sidecar manifest、ffmpeg/ffprobe/whisper-cli/demucs.cpp.main、models、cmudict；bundle 內 ffmpeg/ffprobe `-version` 顯示 `--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`；`otool -L` 顯示 FFmpeg 以 `@rpath` shared dylib + dynamic `libmp3lame.0.dylib` 載入，demucs.cpp.main 僅連系統 `Accelerate.framework`、`libc++`、`libSystem`。已跑 CT-09 license gate 25 components ✅。
- [x] 9.2 打包未簽章 macOS release build＋撰寫略過 Gatekeeper 操作說明（`xattr -cr` 或右鍵開啟）
  【`[需要回報]`（首次發布產物，回報操作說明是否好懂；使用者無 Apple Developer 帳號，2026-07-04 已選定免簽章路線，不涉及憑證/正式對外分發）｜Non-scope：不做 Apple 官方簽章/notarization、不上架 Mac App Store（v1 直發，見 requirement.md Non-scope 9）｜驗證：AT-09-03（未簽章 build→使用者略過 Gatekeeper→全流程 REQ-01→08 可跑）】
  - **進度註記（2026-07-08）**：新增 `scripts/make_release_zip.py`（先檢查 release `.app` 與 sidecar 必要檔，再用 macOS `ditto -c -k --sequesterRsrc --keepParent` 產 unsigned zip 與 `.sha256`）與 `scripts/test_make_release_zip.py`（3 tests，已納入 `scripts/ci_core_checks.sh`）；新增 `release/README-unsigned-macos.md` 說明右鍵打開與 `xattr -cr`。目前因 9.1 release `.app` 尚未產生，`python3 scripts/make_release_zip.py --dry-run` 對預設路徑正確 fail-closed，9.2 維持未勾選直到 release build 完成並實際產 zip。
  - **完成註記（2026-07-11）**：`python3 scripts/make_release_zip.py --dry-run` ✅，實跑 `python3 scripts/make_release_zip.py` 產出 `dist/SyllableRepeater-macos-x86_64-unsigned.zip`（524MB）與 `.sha256`；SHA-256 = `38de745c051c7d19f11c254fe0406055979dbca7c4e6c07ef4474f2f670db8a2`。`unzip -l` 確認 zip 以 `syllable_repeater_app.app/` 為根並包含 sidecar 必要檔。`dist/` 已加入 `.gitignore`，release artifact 保留本機、不進版控。

---

## 3. 前端任務拆分原則與粒度約定

- 適中粒度：每任務聚焦一個可獨立驗證的元件/功能點；單一職責；完成即有驗收要點。
- 與 `frontend-design.md` 功能點 1–8 一一對應；介面消費一律引用「backend-design.md §3.2 介面 N」編號（專案卡 `decision_設計階段無伺服器簡化路徑適配` 之追溯規則）。
- UI 不含業務規則；型別直接複用 domain 套件。

## 4. 前端任務清單（按功能點分組）

## 功能點 0：共享資源（殼層/Token/錯誤）

- [x] **建立 App 殼層與導航**
  - **File**: `app/lib/main.dart`、`app/lib/shell/`
  - **Work**: ProviderScope＋infra 注入；NavigationRail 殼層；最小視窗 1100×700
  - **Purpose**: 全 feature 承載容器
  - **進度註記（2026-07-05）**：ProviderScope、NavigationRail、最小視窗約束建立；`InfraAnalysisRunner` 於 `main.dart` 依 `SidecarPaths.dev()` 就緒時覆寫 `analysisRunnerProvider`；tab 索引提升為 `appShellSelectedIndexProvider`（Notifier），FP2 done 可切 editor。
  - _Leverage: backend-design §2.1 架構圖_｜_Requirements: REQ-09_
  - 【`[可直接做]`｜Non-scope：不做手機版面｜驗證：App 啟動顯示殼層】
- [x] **建立設計 Token 與共享元件**
  - **File**: `app/lib/shared/tokens.dart`、`shared/EmptyState`、`shared/player/`
  - **Work**: 主色/警示色/差異色/圓角/間距固化；空態元件；播放控制條
  - **Purpose**: UI 一致性基準（frontend-design 三-3）
  - **進度註記（2026-07-05）**：`tokens.dart` 與 `EmptyState` 已建立；`shared/player/player_bar.dart` 最小殼落地（idle/loading/playing 三態＋播放/停止回呼，真播放邏輯留 S2）。
  - _Leverage: Material 3_｜_Requirements: 全域_
  - 【`[可直接做]`｜Non-scope：不做主題編輯器｜驗證：Token 對照 frontend-design 值】
- [x] **實作全域錯誤碼→文案/策略映射**
  - **File**: `app/lib/shared/error/`
  - **Work**: 17 個錯誤碼（backend-design §3.2.8）逐碼處理策略；通則「就地顯示、不清空已填資料」
  - **Purpose**: 功能點 8 落地
  - **進度註記（2026-07-05）**：`app/lib/shared/error/error_messages.dart` 已覆蓋 17/17 錯誤碼，widget test 驗證數量。
  - _Leverage: backend-design §3.2.8_｜_Requirements: 各 REQ 3.2.7 錯誤輸入情境_
  - 【`[可直接做]`｜Non-scope：無｜驗證：17/17 碼有對應處理（frontend-design 自檢第 6 項）】

## 功能點 1：課件庫與今日到期（library）

- [x] **實作 LibraryScreen（到期清單置頂＋課件清單）**
  - **File**: `app/lib/features/library/`
  - **Work**: `dueList`（介面 14）掛載/回前景查詢；priority 排序；**不顯示逾期字樣**（M7 介面落地）；空態引導匯入
  - **Purpose**: 「一打開就看到今天該練什麼」（REQ-08 3.1 動機）
  - **進度註記（2026-07-06）**：已新增 `LibraryScreen`、`libraryDueListProvider` 與 `libraryLessonEntriesProvider`，畫面置頂顯示今日到期清單，空態不顯示逾期/懲罰字樣；課件清單讀 `lesson_registry`，點課件會 open `.abopack`、hydrate 同一 `Lesson` 到 editor/practice，再切 tab。widget test 覆蓋 due item、歸檔確認、課件入口、pack hydrate 與 S6 round-trip。回前景重查 dueList 可留後續增強，但不得新增逾期/失敗/懲罰欄位或文案。
  - _Leverage: EmptyState、DueGroup 型別_｜_Requirements: REQ-08_
  - 【`[可直接做]`｜Non-scope：不做搜尋/分頁（單人本機量小）｜驗證：AT-08-02（無催促/懲罰文案）】

## 功能點 2：匯入與分析（import_analysis）

- [x] **實作 ImportScreen（拖放＋選檔＋字稿＋選項）**
  - **File**: `app/lib/features/import_analysis/`
  - **Work**: DropZone（desktop_drop）；副檔名/時長前置檢查；separateVocals 勾選；確認後鎖定按鈕
  - **Purpose**: 2 步完成匯入（動機：一分鐘內開始練）
  - **進度註記（2026-07-05）**：拖放、選檔、字稿、separateVocals、確認鎖定與副檔名檢查建立；時長前置檢查以 `FfprobeDurationProbe` 落地——UI 選/拖檔後即擋 >10 分鐘，錯誤就地顯示、字稿與勾選不清空。
  - _Leverage: 介面 1 輸入欄位表_｜_Requirements: REQ-01_
  - 【`[可直接做]`｜Non-scope：不做批次匯入｜驗證：AT-01-03/05；FfprobeDurationProbe 單元測試 9 情境全綠】
- [x] **實作階段化進度與結果預覽**
  - **File**: 同上 `widgets/staged_progress.dart`
  - **Work**: 訂閱 `Stream<AnalysisEvent>`（介面 1）；decoding/separating/transcribing/syllabifying 文案；失敗顯示錯誤碼文案＋「重試此階段」；done 導向編輯器
  - **Purpose**: 等待黑箱＝最大阻力點的對策
  - **進度註記（2026-07-05）**：`InfraAnalysisRunner` 注入真 `AnalysisPipeline` 走 FFmpeg→whisper.cpp→CMUdict；`PipelineCheckpoint` 分階段 checkpoint 落地——`failed` 事件帶 checkpoint、UI 顯示「重試此階段」按鈕，跳過已完成階段（AT-01-04 落地）；done 顯示「進入編輯器」按鈕，切換 tab 到 `EditorScreen`（不搶焦點自動跳）。
  - _Leverage: 錯誤映射表_｜_Requirements: REQ-01_
  - 【`[可直接做]`｜Non-scope：不做背景排隊多任務｜驗證：AT-01-01（完成列 11 音節）、AT-01-04；domain 3 checkpoint tests 全綠；真 e2e demo 待使用者在裝有 Xcode 的機器跑 `flutter run -d macos` 手動驗證】

## 功能點 3：波形校正編輯器（editor）

- [x] **實作 WaveformCanvas（CustomPaint 波形＋邊界層）**
  - **File**: `app/lib/features/editor/widgets/waveform_canvas.dart`
  - **Work**: peaks 渲染；邊界線 hit-test 拖動手勢；RepaintBoundary 分層；needsReview 警示色
  - **Purpose**: REQ-02 核心互動面
  - **進度註記（2026-07-06）**：peaks bar 渲染＋needsReview 灰底＋邊界線＋拖動預覽線；`onPanDown` hit-test ±12dp 命中最近邊界；RepaintBoundary 分層。實機 30fps 待 macOS 手動觀測（App Sandbox 已 waive 到 M9，見 memory `decision_macos_sandbox_ui_demo_waived_v1`）。
  - _Leverage: 3.5 peaks、tokens_｜_Requirements: REQ-02_
  - 【`[可直接做]`｜Non-scope：不做縮放平移（v1 固定整句視圖）｜驗證：拖動 ≥30fps（REQ-02 3.2.6）；`app/test/editor/waveform_canvas_test.dart` 3/3 全綠】
- [x] **實作邊界校正流程（拖動→吸附→存回→undo）**
  - **File**: `app/lib/features/editor/editor_controller.dart`
  - **Work**: onPanEnd 呼叫介面 2；`ERR_BOUNDARY_INVALID` 回彈動畫；⌘Z undo 堆疊；拖動中毫秒即時顯示；連續拖動取最終值
  - **Purpose**: 「拖一下就修好、改壞可回去」（REQ-02 動機/阻力點）
  - **進度註記（2026-07-06）**：`EditorController` (Riverpod Notifier) 完成 dragStart/dragUpdate/dragEnd/undo/clearError；監聽 pipeline done 自動 loadFrom 初始化；`ERR_BOUNDARY_INVALID` 回彈原值＋SnackBar；⌘Z（macOS Meta）/^Z（其他）走 `Focus.onKeyEvent`。
  - _Leverage: 介面 2 欄位表_｜_Requirements: REQ-02_
  - 【`[可直接做]`｜Non-scope：業務驗證不在 UI 重算（開區間規則歸 Domain）｜驗證：AT-02-01～05；`app/test/editor/editor_controller_test.dart` 7/7 全綠】
- [x] **實作單音節試聽與韻律疊圖顯示**
  - **File**: `app/lib/features/editor/widgets/prosody_overlay.dart`
  - **Work**: 點音節→介面 4 試聽（≤200ms 啟動）；介面 7 疊圖（音高曲線/重音；pitchAvailable=false 顯示徽章）
  - **Purpose**: 校正即時驗證＋S4 視覺化
  - **進度註記（2026-07-06）**：S2 已把 SyllableChipsRow 試聽接成真 `PracticeEngine.singleSyllableStep` + `PracticePlayer.playStep(... repeatN: 1)`；S4 已新增 `ProsodyOverlayControls`，`EditorController` 在 analysis done / 邊界校正 / undo 後同步 `AsyncValue<Prosody>`，`WaveformCanvas` 疊圖顯示 pitch curve、stress markers 與 invalid/NaN 音節灰底；`pitchAvailable=false` 顯示「音高不可用」徽章而非錯誤。
  - _Leverage: 4.7 試聽輔助、介面 7 欄位表_｜_Requirements: REQ-02、REQ-05_
  - 【`[可直接做]`｜Non-scope：不做疊圖匯出圖片｜驗證：AT-05-01/02】

## 功能點 4：句尾疊加練習（practice）

- [x] **實作 PracticeScreen 步驟導航與播放**
  - **File**: `app/lib/features/practice/`
  - **Work**: buildSteps（介面 3）；StepNavigator（11 步顯示音節文字）；PlayerBar（renderStep→just_audio ×N；repeatN Stepper 1–10 預設 3）；切步先 stop
  - **Purpose**: 「第 1 步即點即聽」（REQ-03 動機）
  - _Leverage: 介面 3/4、shared/player_｜_Requirements: REQ-03_
  - 【`[可直接做]`｜Non-scope：不做自動連播全步（v1 手動導航）｜驗證：AT-03-01/03/05/06】
- [x] **實作錄音比對面板與疊圖**
  - **File**: `app/lib/features/practice/widgets/record_panel.dart`、`overlay_chart.dart`
  - **Work**: record 套件錄音＋電平表；錄音中原音鈕置灰；停止→介面 8 比對；OverlayChart 雙波形/音高＋diffRanges 標色；切步/卸載中止並丟棄
  - **Purpose**: 「差在哪一段」看得見（REQ-06 動機）
  - _Leverage: 介面 8 欄位表、tokens 差異色_｜_Requirements: REQ-06_
  - 【`[可直接做]`｜Non-scope：不保留錄音（M10；Domain 已刪，UI 不另存）｜驗證：AT-06-01/02/03/05】
  - **進度註記（2026-07-06）**：已新增 `practice_recording.dart`（record 套件錄 WAV、level stream、`PracticeComparisonService`）、`RecordPanel`、`OverlayChart`，並接入 `PracticeScreen`。`PracticeController` 錄音中停用 playback，停止後呼叫 compare 並顯示節奏/語調差異與疊圖；過短錄音保留錯誤、`comparison=null`；錄音中切步會 cancel 並清空暫存狀態；macOS 已補 `NSMicrophoneUsageDescription` 與 audio-input entitlement，未更動 app sandbox。
- [x] **實作難度結算列（困難/普通/輕鬆）**
  - **File**: `app/lib/features/practice/widgets/settle_bar.dart`
  - **Work**: 介面 13 settle；顯示回傳 nextDue（「下次：7/8」）
  - **Purpose**: SRS 閉環入口
  - **進度註記（2026-07-06）**：已新增 `SettleBar` 並接入 `PracticeScreen`，三個按鈕呼叫 `ProgressService.settle`，成功後顯示 nextDue；`PracticeScreen` 依目前 lesson/step 建出穩定 `PracticeGroup`，`SettleBar` 結算前先呼叫 `ProgressService.ensurePracticeGroup`，`DriftProgressRepository.saveGroup` 會替未註冊 lesson 建最小 `lesson_registry` row。`app/test/progress/progress_ui_test.dart` 覆蓋「普通」按鈕與 ensure group。
  - _Leverage: 介面 13_｜_Requirements: REQ-08_
  - 【`[可直接做]`｜Non-scope：不顯示任何失敗/懲罰語彙（M7）｜驗證：AT-08-01】

## 功能點 5：匯出（export）

- [x] **實作匯出對話框（勾選→路徑→進度→完成）**
  - **File**: `app/lib/features/export/export_dialog.dart`
  - **Work**: 步驟勾選清單（未勾置灰）；macOS 存檔對話框；介面 5/6 呼叫；完成顯示路徑＋「在 Finder 顯示」＋silenceGapsMs 摺疊資訊；`ERR_EXPORT_*` 就地處理、勾選保留
  - **Purpose**: 3 步匯出離線練習檔（REQ-04 動機）
  - _Leverage: 介面 5/6 欄位表_｜_Requirements: REQ-04_
  - 【`[可直接做]`｜Non-scope：不做匯出歷史紀錄｜驗證：AT-04-01～05】

## 功能點 6：課件儲存/開啟與譯文（pack_translate）

- [x] **實作課件儲存/開啟（⌘S／⌘O）與譯文編輯**
  - **File**: `app/lib/features/pack_translate/`
  - **Work**: 介面 9/10；`ERR_PACK_CORRUPTED` 整頁錯誤態不部分渲染；譯文欄手動輸入即標 manual；「自動翻譯」鈕（介面 12）未設 key 停用＋tooltip；ai 回應晚於手動輸入則丟棄
  - **Purpose**: 「沒設 key 也永遠能手動」（REQ-07 阻力點對策）
  - **進度註記（2026-07-06）**：已在 `LibraryScreen` 放入 FP6 UI shell：手動譯文輸入永遠可編輯，自動翻譯鈕未設 key 停用並顯示 tooltip。新增 `lesson_pack_service.dart`，以 `LessonPackEngine + AtomicFileIo + file_selector` 真開啟/儲存 `.abopack`，成功後同步 `lesson_registry`；`AppLessonPackService.open` 先用 Domain `decodeWav` 驗證 pack audio，損毀/解碼失敗顯示 `ERR_PACK_CORRUPTED` 或 `ERR_DECODE_FAILED` 且不覆蓋現有 UI state。新增 `lesson_session_controller.dart`，開啟/課件卡/儲存後 hydrate 同一 `Lesson` 到 editor/practice，單音節試聽與 PracticeScreen 優先使用 pack session PCM/peaks；`CallbackShortcuts` 已接 ⌘O/⌘S 與 Ctrl+O/Ctrl+S。AI 回應與 manual 覆蓋仍維持 Domain `mergeTranslation` 規則；真 provider adapter 待 7.2 外部契約確認。
  - _Leverage: 介面 9/10/12 欄位表_｜_Requirements: REQ-07_
  - 【`[可直接做]`｜Non-scope：不做多語譯文（v1 單目標語 zh-TW 預設）｜驗證：AT-07-01～04/06】

## 功能點 7：進度、SRS 與設定（progress_settings）

- [x] **實作歸檔管理與進度匯入匯出**
  - **File**: `app/lib/features/progress_settings/`
  - **Work**: 歸檔前確認對話框；ARCHIVED 顯示 168h 恢復倒數；EXPIRED 恢復鈕不可用；介面 15/16；MergeSummary 對話框（applied/skipped/resetLessons 列名）
  - **Purpose**: 誤歸檔可反悔、合併結果透明（M6/M8 介面落地）
  - **進度註記（2026-07-06）**：Domain/infra 介面已可用（`ProgressEngine.archive/restore/exportProgress/importProgress` + `DriftProgressRepository`）；`ProgressSettingsScreen` 已接 `file_selector` 匯出/匯入 `.aboprogress`，匯入後顯示 MergeSummary 對話框與頁面回顯；`LibraryScreen` 歸檔前會跳確認對話框，設定頁顯示 ARCHIVED 168h 恢復倒數，EXPIRED 恢復鈕停用。widget test 已覆蓋匯入匯出、歸檔確認、倒數與恢復。
  - _Leverage: 介面 15–18 欄位表_｜_Requirements: REQ-08_
  - 【`[可直接做]`｜Non-scope：不做自動排程備份（使用者手動匯出）｜驗證：AT-08-03/05/06/07】
- [x] **實作設定頁（提醒三參數／AI key／sidecar 逾時）**
  - **File**: 同上 `settings_screen.dart`
  - **Work**: 三參數控件預設 15/5/2（介面 19）；AI key obscure 輸入→介面 11 送出即清空欄位（UI 不留副本）；sidecar.timeoutSec 設定
  - **Purpose**: Q9 可調落地＋M10 key 安全
  - **進度註記（2026-07-06）**：提醒三參數 UI 已落地於 `app/lib/features/progress/progress_settings_screen.dart`，保存後寫 app_settings 並觸發 audit log，widget test 覆蓋讀寫；AI key obscure 輸入已接 `AiSettingsService.configureCredential`，送出後清空欄位，當前使用 `InMemoryAiSecureStore` + `NoopAiClient` 走 `AIService.configure` 與 audit，不實作真 HTTP/Keychain；`SidecarConfig.timeoutSeconds` 已於 Domain/Drift/app_settings/UI stepper 落地，保存寫 `sidecar_config_changed` audit。真 Keychain/provider adapter 仍待服務商契約與 key 安全路徑回報後再做。
  - _Leverage: 介面 11/19_｜_Requirements: REQ-07、REQ-08_
  - 【`[可直接做]`｜Non-scope：key 不做「顯示已存值」（Keychain 單向）｜驗證：AT-07-05、Q9 設定往返】

## 真 App REQ-01→08 驗收修繕（2026-07-12）

- [x] **S6-22.1 課件庫改為啟動首頁，重排開啟課件與資訊窗格**
  - **File**：`app/lib/shared/navigation.dart`、`app/lib/features/library/library_screen.dart`
  - **Work**：啟動預設 `AppSection.library`；首頁同一水平左側提供 `.abopack` 開啟，右側顯示標題、檔名、音節數、譯文、更新時間；下方保留到期清單與課件清單。
  - **驗證**：`app/test/widget_test.dart`、`app/test/progress/progress_ui_test.dart`；`flutter run -d macos` 以 1100×700 真 App 截圖確認無重疊/裁切。
- [x] **S6-22.2 設定頁集中課件與進度檔案管理**
  - **File**：`app/lib/features/progress/progress_settings_screen.dart`
  - **Work**：把手動譯文與「儲存課件」移入設定的檔案管理區，與 `.aboprogress` 匯入/匯出並列；沿用同一 `LessonPackService` / `ProgressService`，不複製業務邏輯。
  - **驗證**：設定頁儲存課件帶入 manual translation、進度匯入/匯出與 S6 round-trip widget tests 通過。
- [x] **S6-22.3 AT-04-07 匯出全部選取／取消與實檔存在 gate**
  - **File**：`app/lib/features/export/export_dialog.dart`、`packages/infra/lib/src/practice/practice_exporter.dart`
  - **Work**：匯出視窗新增全部選取／全部取消與已選數；Atomic write 後再確認目的檔存在，缺檔映射 `ERR_EXPORT_DEST_UNWRITABLE`。
  - **驗證**：`app/test/export/export_dialog_test.dart`、`packages/infra/test/practice_exporter_test.dart`；release LGPL FFmpeg 已獨立實寫 16,971-byte MP3，新增 `FFMPEG_PATH` 真 exporter 測試供可用環境執行。
- [x] **S6-22.4 AT-06-06 macOS 錄音收尾等待與記憶體試聽**
  - **File**：`app/lib/features/practice/practice_recording.dart`、`practice_controller.dart`、`practice_player.dart`、`widgets/record_panel.dart`
  - **Work**：stop 後等待 WAV 可完整 decode；失敗刪來源檔；成功 PCM 僅留目前步驟記憶體，新增「播放錄音」，一次性播放 WAV 於播放後刪除，切步/重錄清空。
  - **驗證**：`practice_recording_test.dart`、`practice_controller_test.dart`、`practice_player_test.dart`、`practice_screen_test.dart`；維持 M10 磁碟不保留錄音。
- [x] **S6-22.5 `.aboprogress` 對齊 ZIP＋`progress.json` 契約**
  - **File**：`packages/domain/lib/src/progress/progress_engine.dart`
  - **Work**：新輸出改為 ZIP 單 entry `progress.json`；匯入先解 ZIP/驗 schema 再交易合併，並保留預發布純 JSON legacy 讀取相容；M6 merge 規則不變。
  - **驗證**：`packages/domain/test/progress_import_export_test.dart` 5/5 通過，含 entry、敏感資料掃描、updatedAt、contentHash、損毀檔零副作用。
- [x] **S6-22.6 完整 CI 與 x86_64 release zip 重建**
  - **Work**：執行 `bash scripts/ci_core_checks.sh` 全綠後，重跑 `flutter build macos --release --no-pub` 與 `python3 scripts/make_release_zip.py`，更新 zip SHA-256，確認新首頁/錄音/匯出修繕已進 release artifact。
  - **完成註記（2026-07-12）**：`bash scripts/ci_core_checks.sh` ✅（guardrails、handoff、CT-09、domain 82、infra 74、app 75、`flutter analyze` 全綠）；`flutter build macos --release --no-pub` ✅ 產出 x86_64 `syllable_repeater_app.app` 634MB；bundle 內 FFmpeg 8.1.2 為 `--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`，`otool -L` 顯示 `@rpath` shared dylib 與 dynamic `libmp3lame.0.dylib`；bundle 內 demucs.cpp.main 僅連系統 `Accelerate.framework`、`libc++`、`libSystem`；以 bundle FFmpeg 跑 `practice_exporter_test.dart` ✅ 6/6；`python3 scripts/make_release_zip.py` ✅ 產出 `dist/SyllableRepeater-macos-x86_64-unsigned.zip` 524MB，SHA-256 `949c76cfdaf8b0e72702dabecca777110806aa01c7a27c17cc238f9dc12a383c`，`unzip -l` 核對 zip 內含 sidecar manifest、ffmpeg、whisper、demucs、兩個模型與 cmudict。

---

## 5. 依賴關係與時序建議（任務級）

| 任務 | 型別 | 前置任務 | 阻塞/外部依賴 | 建議順序 | 設計章節 |
|------|------|----------|---------------|----------|----------|
| 後端 1.1–1.4 | 後端 | — | — | ①（S0 起手） | BE §1.5/§3.1 |
| 後端 2.1 | 後端 | — | sidecar 二進位取得＋授權核對（OQ-1/2 部分） | ① 並行 | BE §2.2 |
| 後端 2.2–2.3 | 後端 | 1.1、2.1 | — | ②（S0 完成＝demo 崩潰隔離） | BE §3.2.1 |
| 後端 3.1–3.5 | 後端 | 2.2–2.3 | 3.2 受 OQ-1 模型選擇影響 | ③（S1a） | BE §3.2.1 |
| 前端 FP0 三卡 | 前端 | 1.1 | — | ③ 並行 | FE 二/三 |
| 前端 FP2 | 前端 | 3.4、FP0 | — | ④（S1a demo：列 11 音節） | FE 功能點 2 |
| 後端 3.6–3.7 | 後端 | 3.3 | — | ⑤（S1b） | BE 介面 2 |
| 前端 FP3（畫布＋校正） | 前端 | 3.5–3.7、FP0 | — | ⑤（S1b demo） | FE 功能點 3 |
| 後端 3.8 | 後端 | 3.4、2.1 | OQ-2 demucs 選定 | ⑥（S1c，可與 ⑦ 並行） | BE §3.2.1 |
| 後端 4.1–4.4 | 後端 | 3.3（音節結構定型） | — | ⑦（S2；TDD 先紅後綠） | BE §3.2.2 |
| 前端 FP4（導航播放） | 前端 | 4.2、4.4、FP0 | — | ⑦（S2 demo：11 步原聲） | FE 功能點 4 |
| 後端 4.5–4.7 | 後端 | 4.4、2.3 | — | ⑧（S3） | BE 介面 5/6 |
| 前端 FP5 | 前端 | 4.6 | — | ⑧（S3 demo） | FE 功能點 5 |
| 後端 5.1–5.2 | 後端 | 3.3 | — | ⑨（S4，可與 ⑧ 並行） | BE §3.2.3 |
| 前端 FP3（疊圖） | 前端 | 5.1–5.2、4.7 | — | ⑨（S4 demo） | FE 功能點 3 |
| 後端 6.1–6.2 | 後端 | 4.4、5.2（pitch 供 intonation） | 麥克風權限（Info.plist） | ⑩（S5；TDD） | BE §3.2.4 |
| 前端 FP4（錄音比對） | 前端 | 6.2 | record 套件授權核對 | ⑩（S5 demo） | FE 功能點 4 |
| 後端 7.1 | 後端 | 3.3、5.1（prosody 入 pack） | — | ⑪（S6） | BE 介面 9/10 |
| 後端 7.2 | 後端 | 1.1 | AI 服務商 API（使用者 key） | ⑪ 並行 | BE 介面 11/12 |
| 後端 7.3–7.6 | 後端 | 1.2、1.4 | schema 確認（OQ-3） | ⑪ 並行 | BE §3.2.6 |
| 前端 FP6、FP1、FP7 | 前端 | 7.1–7.6 | — | ⑫（S6 demo） | FE 功能點 1/6/7 |
| 後端 8.1 | 後端 | 1.1 | — | ② 即建立、全程常駐 | BE §4.4 |
| 後端 8.2 | 後端 | 各模組完成 | — | 隨切片累積、⑫ 收齊 | BE §4.4 |
| 後端 8.3 | 後端 | 3.4 | i5-8259U 實測 | ④ 後即可跑（回填 Q10） | BE §5.1-1 |
| 後端 9.1–9.2 | 後端 | 全部 | 無（9.2 已改免簽章路線，不再依賴 Apple 開發者帳號） | ⑬（收尾） | BE §1.5 |

**聯調視窗**：每個切片末＝一次前後端聯調＋demo（S1a 列 11 音節／S2 播 11 步原聲／S3 靜音實測／S5 疊圖標色／S6 課件 round-trip）。

**關鍵路徑**：1.1→2.2→3.3→4.1–4.4→FP4 播放（S2 是產品核心價值首次可體驗點）；3.2（whisper 契約）受 OQ-1 影響，宜最早實測定案。

## 6. 開放問題與需人工確認

- **OQ-1（已解決，2026-07-04）**：whisper.cpp 模型檔選型——使用者指定僅用 `small.en`。S1a 已下載 `ggml-small.en.bin` 至 `.local-tools/whisper.cpp/models/`；Intel Mac 上 mp3+Metal 初跑輸出異常，改以 FFmpeg 轉 16k mono WAV 並用 `--no-gpu`，對 `step up your coding skills to a new level` 辨識正確（約 3.48s）。
- **OQ-2（已解決，2026-07-06）**：demucs.cpp 移植版選定＝[sevagh/demucs.cpp](https://github.com/sevagh/demucs.cpp)。**LICENSE 核對結果 = MIT License, Copyright (c) 2023 Sevag H**（透過 hard-guardrails skill 的 WebFetch 直接讀 https://raw.githubusercontent.com/sevagh/demucs.cpp/main/LICENSE），無 non-commercial 或 share-alike 條款；主依賴 Eigen 為 MPL-2.0（檔案級 copyleft，對主程式不傳染）——皆通過 M9 授權白名單。使用者本機 build 與模型下載屬環境準備事宜，adapter code + 假 runner 測試 + integration skip 模式已就位（S1c-2/3/4）；hard-limits-matrix #12 Dependency Scanning PARTIAL 進度補至 IMPLEMENTED（詳見 memory `decision_demucs_cpp_selected_mit_licence`）。
- **OQ-3**：Drift schema V1（任務 1.2，依規標 `[必須確認]`）——新建本機 SQLite、無既有資料；**使用者核可本 task-split 即視為確認**，後續 schema 變更另行確認。
- **OQ-4（已解決，2026-07-04）**：原「任務 9.2 簽章/notarization 需 Apple Developer 帳號」——使用者無該帳號，於免簽章＋略過 Gatekeeper／免費 Apple ID Personal Team ad-hoc／桌面版走 Flutter Web PWA／延後至取得帳號再付費申請，四個選項中選定**「免簽章＋略過 Gatekeeper」**。任務 9.2 已改為打包未簽章 build＋操作說明，不再依賴 Apple 帳號；正式簽章／notarization 延後至取得帳號後再評估（見 requirement.md v1.2 修訂歷史、backend-design.md §6 開放問題第 3 項）。

---

*自我檢查：章節順序符合標準（概覽→後端→前端原則→前端→依賴→開放問題）；編號連續；每任務三欄齊備；無任務涉及需求 2.4 Non-scope 項目；TDD 任務（4.1/4.3/4.5/6.1）先於對應實作；CT-01～10 全數有承接任務（8.2）。*
