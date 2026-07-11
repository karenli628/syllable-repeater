# 程式碼審查報告（全專案 QA・六面向）

## 基本資訊

| 專案 | 內容 |
|------|------|
| 需求名稱 | 語音/歌曲/台詞模仿練習系統（Syllable Repeater）macOS v1（`syllable-practice-macos-v1_20260704`） |
| 審查日期 | 2026-07-07 |
| 審查輪次 | 第 1 輪（全專案 QA，非單次變更審查） |
| 審查範圍 | 全端（domain 純 Dart／infra sidecar・DB／app Flutter macOS／scripts／CI／guardrails／spec 文件） |
| 變更檔案數 | 全庫：lib 82 個 dart 檔（不含產生碼）＋46 個測試檔＋6 個 scripts＋CI/hooks |
| 設計檔案 | backend-design.md ✅ ／ frontend-design.md ✅ |
| 編譯闸門 | ✅ HEAD `8cf46dd` GitHub Actions Core CI run `28836556481` 全綠（domain 82／infra 67／app 59 tests＋`flutter analyze` 無問題） |
| 審查基準 | requirement.md v1.3（M1–M10、CT-01～10）／backend-design 介面 1–19＋§3.2.8／frontend-design 功能點 1–8／task-split.md／hard-limits-matrix.md（37 項）／cross-cutting-review CC-*／change-defense 六面向 |

> 技術堆疊差異聲明：本專案為 Dart/Flutter，BE-*（Java/Spring/MyBatis）與 FE-*（Vue/TS）檢查項字面不適用，依 SKILL.md「與專案既有規範衝突以專案規範為準」原則，改以其**精神等價項**（分層、命名、null 安全、錯誤處理、AI-Generate 標註）＋ CC-*／BQ-*／FQ-*／IA-*／六面向執行。

## 審查結論

**✅ 透過**（blocking 0、important 2 ≤ 2）——可依序完成剩餘任務（2.1／7.2／9.1／9.2）後進入 `project-archive`；2 條 important 建議在下個開發 session 一併修復（皆為小改動）。

### 統計概覽

| 嚴重性 | 數量 |
|--------|------|
| blocking | 0 |
| important | 2 |
| suggestion | 4 |
| nit | 1 |
| learning | 2 |
| praise | 7 |

## 設計實作一致性

### 後端設計對照（backend-design §3.2 介面 1–19）

| 設計項 | 狀態 | 說明 |
|--------|------|------|
| 介面 1 `AnalysisPipeline.analyze`（Stream 事件＋重入鎖） | ✅ 已實作 | `packages/domain/lib/src/analysis/analysis_pipeline.dart`；另實作設計未列的 checkpoint 續跑（正向超出，見偏差記錄） |
| 介面 2 `updateSyllableBoundary`（開區間＋零交越） | ✅ 已實作 | `alignment_engine.dart:64`；吸附後 clamp 回開區間 |
| 介面 3–6 `buildSteps/renderStep/exportStep/exportMerged` | ✅ 已實作 | `practice_engine.dart`＋infra `practice_exporter.dart`（M1/M2/M3 防線） |
| 介面 7 `ProsodyAnalyzer.analyze`（pitch 可降級） | ✅ 已實作 | `prosody_analyzer.dart`；NaN 標記無效音節（AT-05-03） |
| 介面 8 `RecordingComparator.compare`（finally 刪錄音） | ✅ 已實作 | `recording_comparator.dart:75`（M10） |
| 介面 9/10 `LessonPackEngine.write/read` | ✅ 已實作 | round-trip／損毀不部分載入測試齊 |
| 介面 11/12 `AIService.configure/translate` | ⚠️ Domain 完成、真 adapter 未接 | task 7.2 未勾——Keychain／HTTP adapter 待外部契約回報，**誠實標註未假完成** |
| 介面 13–19 `ProgressEngine` 全套 | ✅ 已實作 | settle／dueList／import・export／archive・restore／reminderConfig |
| §3.1.2 Drift schema 五表＋V2 audit_log | ✅ 已實作 | `app_database.dart` 逐欄一致；tableName 覆寫對齊單數表名 |
| §3.2.8 錯誤碼 17 碼 | ✅ 已實作 | `errors.dart` 17/17；惟部分場景**借用碼**（見 I-002） |
| §4.4 核心防線對照表 M1–M10 | ✅ 三同步成立 | 逐條有程式防線＋測試（詳見下方核心維持原則核對） |

### 前端設計對照（frontend-design 功能點 1–8）

| 設計項 | 狀態 | 說明 |
|--------|------|------|
| FP0 殼層／tokens／17 碼錯誤映射 | ✅ | `error_messages.dart` 17/17（widget test 驗數量） |
| FP1 課件庫（無逾期字樣，M7 介面落地） | ✅ | `library_screen.dart` |
| FP2 匯入（前置雙保險＋階段化進度＋重試此階段） | ✅ | `import_screen.dart`／`staged_progress.dart` |
| FP3 波形校正（hit-test、undo、回彈）＋韻律疊圖 | ✅ | `waveform_canvas.dart`／`editor_controller.dart`（undo 堆疊在 UI，Domain 無狀態，符合設計） |
| FP4 練習（切步先 stop、錄音防串音、疊圖標色） | ✅ | `practice_controller.dart`（playRunId 防競態） |
| FP5 匯出（未勾置灰、匯出中鎖、錯誤保留勾選） | ✅ | `export_dialog.dart`＋infra 雙層重入鎖 |
| FP6 課件與譯文（manual 永遠可用、ai 晚到丟棄） | ✅ | `lesson_session_controller.dart`＋Domain `mergeTranslation` |
| FP7 進度設定（168h 倒數、MergeSummary、key 送出清空） | ✅ | `progress_settings_screen.dart` |

## 核心維持原則核對（三同步：文件＝程式＝測試）

| 核心 | 程式防線 | 測試 | 判定 |
|------|----------|------|------|
| M1 原聲不可替換 | `renderStep` 唯一 copy＋串接路徑；`PracticeStep.sourceRanges` 型別上只存 `TimeRange` | CT-01 逐 sample 回歸（`practice_build_steps_test.dart`）常駐 CI | ✅ |
| M2 疊加演算法 | `buildSteps` 純函式，無 word 邊界參數（演算法上不可能吸附） | CT-02（11 步／`tion skills`／5 音節句） | ✅ |
| M3 靜音規則 | `renderMergedExport` 以 sample 數插靜音、回傳 `silenceGapsMs` | CT-03 解碼實測 ±20ms | ✅ |
| M4 崩潰隔離 | `SidecarRunner`：timeout→SIGKILL 回收；signal→`ERR_SIDECAR_CRASHED`；checkpoint 保留已完成階段 | CT-04 kill -9 五情境 | ✅ |
| M5 Domain 純 Dart | `domain_purity_test.dart` 掃 import／pubspec 白名單 | CT-05／AT-09-02 | ✅ |
| M6 合併/局部重置 | `importProgress` 全檔驗證→updatedAt upsert→contentHash 單課 reset；Drift transaction | CT-06 | ✅ |
| M7 跨日零懲罰 | schema 無逾期/失敗欄位（結構防線）；dueList 純查詢 | CT-07＋`db_schema_test.dart` 結構斷言 | ✅ |
| M8 歸檔 168h | 狀態機＋Clock 注入；EXPIRED 不可逆 | CT-08 167h/169h 兩側 | ✅ |
| M9 授權白名單 | `check_licenses.py` gate＋`prepare_release_sidecars.py` 拒 GPL/static FFmpeg；pre-push＋CI | CT-09 注入測試 | ✅（release 實體待 2.1） |
| M10 隱私防線 | compare finally 刪檔；attempt/audit_log schema 無音訊/key 欄位；SecureStore 唯一通道 | CT-10（刪檔斷言＋pack 掃描） | ✅（真 Keychain 待 7.2） |

「不可接受」清單：**零違反**。硬性限制完整性：matrix 37 項 `NOT_REVIEWED=0`、`REJECTED_NEEDS_IMPLEMENTATION=0`、10 條 `APPROVED_NOT_APPLICABLE` 均有 DL 編號＋使用者批准（無 AI 自批）、`IMPLEMENTED` 均附落地檔案——**通過**（惟見 I-001 統計備忘數字）。

## 發現詳情

### Blocking

（無）

### Important

#### [I-001] 六面向・面向 3（數據準確度）：hard-limits-matrix 內部數字不一致（19 vs 20）
- **檔案**: `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md:87`
- **描述**: 狀態統計表（第 66–67 行）為 `IMPLEMENTED=8／PARTIAL=19`，但「交付條件備忘」第 3 點仍寫「**20 條** `PARTIAL`」。回溯 execution-log：S6-11 時統計為 PARTIAL=20，S6-12 把 #8 CI 轉 IMPLEMENTED 後更新了統計表、漏改備忘行。是否同步把備忘改為 19？此表是交付前檢核依據，引用錯數字屬憲法 C3／六面向面向 3 的必修項。
- **建議**: 第 87 行「20 條」→「19 條」；並建議日後更新統計時全文搜尋一次舊數字。
- **規範來源**: 憲法 C3（引用回對原始出處）；change-defense-checklist §面向 3

#### [I-002] CC-ARCH-05／CC-DESIGN-03：`ERR_DECODE_FAILED` 語意漂移（多場景借用同一錯誤碼）
- **檔案**: `packages/infra/lib/src/sidecar/whisper_transcriber.dart:136`、`packages/infra/lib/src/sidecar/demucs_separator.dart:82`、`packages/domain/lib/src/analysis/analysis_pipeline.dart:279`、`app/lib/features/practice/practice_controller.dart:157`（等多處）
- **描述**: backend-design §3.2.8 定義 `ERR_DECODE_FAILED`＝「無法解碼，檔案可能損毀」（觸發模組 AnalysisPipeline）。實作上它被借用於：whisper 轉寫 exit≠0、demucs 未產出 vocals、pipeline 泛型 catch、播放失敗、「尚無可播放 PCM」等前置狀態。UI 依 code 映射顯示「解碼失敗／請確認音檔可播放」，在「辨識失敗」「播放失敗」情境會誤導使用者的排錯方向。是否考慮補足專屬錯誤碼？
- **建議**: 走一次小型變更防線後三同步：backend-design §3.2.8 增列 `ERR_TRANSCRIBE_FAILED`／`ERR_SEPARATE_FAILED`／`ERR_PLAYBACK_FAILED`（或至少前兩者），同步 `errors.dart`、`error_messages.dart`、frontend-design 功能點 8 對照表與測試（error_messages widget test 的碼數斷言記得同步）。過渡期較低成本替代：UI 遇非映射情境改顯示 `DomainException.message`。
- **規範來源**: backend-design §3.2.8（「新增錯誤碼必須同步兩處文件」——`errors.dart:3` 自身註解）；cross-cutting-review CC-ARCH-05

### Suggestion / Nit / Learning

> 以下為最佳化建議，不阻斷。

- **[S-001／CC-SEC・可攜性]** `app/lib/shared/infra/sidecar_paths.dart:102` — `_defaultDevRoot` 寫死開發機絕對路徑 `/Users/karen_files/...` 且已隨 repo 轉 public 對外可見。env var 可覆寫、release 走 bundled（風險受控，且 memory `decision_sidecar_paths_dev_env_override` 有記錄），但：①曝露本機帳號與目錄結構；②他機 clone 後未設 env 會靜默 fallback 到 preview runner。是否考慮改為由執行目錄向上尋找 workspace 根（找 `pubspec.yaml` 內 `name: syllable_repeater_workspace`），或於 README 明示必設 `SYLLABLE_REPEATER_DEV_ROOT`？
- **[S-002／CC-ARCH-03]** `packages/domain/lib/src/analysis/prosody_analyzer.dart:108-165` 與 `packages/domain/lib/src/recording/recording_comparator.dart:135-187` — `_pitchContour`／`_autocorrelationScore`／`_normalizedRms` 兩處近乎相同（約 80 行）。目前參數一致（RMS gate 0.02、score 0.65、80ms 窗），未來調參或 YIN→WORLD 升級時只改一處必分歧。是否抽出 `packages/domain/lib/src/dsp/pitch.dart` 純函式共用？介面不動、測試可沿用。
- **[S-003／CC-PERF]** `packages/infra/lib/src/sidecar/sidecar_runner.dart:69`＋`ffmpeg_decoder.dart:72-76` — stdout 以 growable `List<int>` 收集後經 `Uint8List.fromList`＋`Int16List.fromList` 共三次複製；10 分鐘上限檔（~52M samples）峰值記憶體放大顯著。是否讓 `SidecarRunner` 改用 `BytesBuilder`（`takeBytes()` 零複製）＋ decoder 直接以 view 建 `Pcm`？典型 10 秒課件無感，屬防禦性優化，改動限 infra 兩檔。
- **[S-004／CC-PERF]** `packages/domain/lib/src/recording/recording_comparator.dart:91-95` — `OverlayData.userWave/referenceWave` 帶全解析度樣本（10 秒錄音＝44.1 萬 double × 2 條）交 UI，而 `OverlayChart` 實際只需數百點。是否於 Domain 端先降採樣（可複用既有 `_waveCurve` 160-bucket 邏輯）？可同時降低 Attempt overlay 快照體積。
- **[N-001／面向 6]** `requirement.md` — REQ-02 起各章內部小節編號沿用模板「3.1／3.2…」（如「四、REQ-02」下是「3.1 需求概述」），閱讀時章內編號與章號不對應。AT-xx 編號唯一、追溯不受影響，純文件格式瑕疵。
- **[L-001／learning]** `analysis_pipeline.dart:277` 的泛型 `catch` 統一包成 DomainException 是好防線；搭配 I-002 的專屬錯誤碼後，可再依 `currentCheckpoint()` 內容推斷失敗階段（decodedPcm 有值＝解碼後失敗），讓 failed 事件自帶更準確的碼。
- **[L-002／learning]** `zero_crossing.dart` 的 `kZeroCrossingSearchWindowMs` 常數同時服務切點吸附與 renderStep fade 窗（3.7／4.4 共用）是「單一常數守恆一條規格」的好樣板；後續新增涉及 §0.1 的收尾參數時建議沿用此模式（常數＋雙處引用＋註解標明規格出處）。

### Praise 👏

- `packages/infra/lib/src/db/app_database.dart` — **結構防線**設計出色：M7（無逾期/失敗欄位）、M10（attempt/audit_log 無音訊/key 欄位）用「schema 上不存在」取代「程式邏輯擋」，比防線更硬，且有 `db_schema_test.dart` 結構斷言看守。
- `scripts/ci_core_checks.sh`＋`.github/workflows/ci.yml` — 本機與 GitHub Actions **共用同一條 gate 腳本**（單一來源），杜絕「本機綠、CI 紅」漂移；runner/Flutter 版本 pin 死避免環境漂移。
- `packages/domain/test/domain_purity_test.dart` — M5 policy-as-code 樣板：掃 import＋pubspec＋自我驗證（防線能辨識違規範例），日後接任何 CI 免改。
- `packages/domain/lib/src/analysis/analysis_pipeline.dart` — `PipelineCheckpoint` 失敗續跑設計超出設計稿要求，直接落實 AT-01-04「已完成階段保留」到 UI「重試此階段」。
- `app/lib/features/export/export_dialog.dart`＋`packages/infra/lib/src/practice/practice_exporter.dart` — 匯出重入防護**雙層**（UI `_isExporting` 置灰＋infra `_activeDestPaths`→`ERR_EXPORT_IN_PROGRESS`），且 temp WAV 清理走 finally＋App 啟動 clearTemp 雙保險（AT-04-05／M10 巡檢）。
- 全庫 — `// AI-Generate` 標註 89 檔全覆蓋（coding-standard §6.5／coding_standard §2.3.5）；無 TODO 殘留、無 print 偵錯、無 dynamic 濫用；doc comment 一致引用設計章節編號（如 `backend-design.md §3.2.2`），追溯性極佳。
- `spec-syllable-repeater/.../task/execution-log.md` — 未完成任務（2.1／7.2／9.1／9.2）**誠實不假完成**並記錄原因與待決依賴，是三同步紀律的正確示範。

## 設計偏差記錄

| 偏差型別 | 設計檔案 | 實際實作 | 影響評估 |
|----------|----------|----------|----------|
| 介面契約（正向超出） | 介面 1 輸出僅 stage/progress/result | `AnalysisEvent` 另帶 `waveformPeaks/decodedPcm/checkpoint`，新增 `failed` stage | 對 UI 有利（重試此階段）；欄位為增列不破壞對齊。建議下次設計增修時回寫 backend-design §3.2.1（三同步） |
| 錯誤碼語意 | §3.2.8 碼→模組→語意一一對應 | 多場景借用 `ERR_DECODE_FAILED`（I-002） | 使用者文案誤導；修法見 I-002 |
| 模型欄位 | `AlignmentResult.needsReview: bool`（獨立欄位） | 以 `syllables.any((s) => s.needsReview)` 推導 | 語意等價、無欄位漂移；可接受 |

## 後端業務實作品質審查（BQ-*，依本專案語境轉譯）

### 冪等性（BQ-IDEM）
| 介面 | 設計要求 | 實際實作 | 狀態 |
|------|----------|---------|------|
| analyze | 進行中重入拒絕（AT-01-05） | `_inProgress` 旗標→`ERR_ANALYSIS_IN_PROGRESS` | ✅ |
| exportStep/Merged | 同 destPath 重入拒絕（AT-04-05） | `_activeDestPaths` set→`ERR_EXPORT_IN_PROGRESS` | ✅ |
| importProgress | 同檔重複匯入冪等 | `updatedAt` 相等不覆寫（skipped 計數） | ✅ |
| translate | manual 永遠勝出（AT-07-06） | `mergeTranslation` source 優先序 | ✅ |

### 交易完整性（BQ-TX）
| 交易方法 | 邊界 | 狀態 |
|---------|------|------|
| `DriftProgressRepository.saveProgressSnapshot` | `_db.transaction` 清舊表→套用（drift_progress_repository.dart:143） | ✅ |
| settle/saveGroup/audit | 單寫或 transaction 包裹；audit 與主寫同 repo | ✅ |
| 檔案寫入 | 一律 temp→rename 原子搬移（`AtomicFileIo`），失敗清 tmp | ✅ |

### 資料一致性（BQ-CONSIST）
| 場景 | 方案 | 狀態 |
|------|------|------|
| 進度合併 | 全檔驗證→交易套用；resetLessons 透明回報 | ✅ |
| pack round-trip | contentHash 重算＋schemaVersion 驗證＋不部分載入 | ✅ |

### 並發安全（BQ-CONCUR）
| 資源 | 鎖策略 | 狀態 |
|------|--------|------|
| 播放切換 | `_playRunId` 世代編號防過期回呼（practice_controller.dart:162） | ✅ |
| 錄音生命週期 | 切步/卸載 cancel＋暫存丟棄 | ✅ |

### 重試與超時（BQ-RETRY）
| 外部呼叫 | 超時 | 降級 | 狀態 |
|---------|------|------|------|
| FFmpeg/whisper/demucs | 預設 120s／240s，可設定（sidecar.timeoutSec） | demucs 失敗跳過分離；whisper 失敗 checkpoint 重試 | ✅ |
| AI 服務商 | rate limit＋host allowlist＋https-only＋注入 sanitizer | 失敗不阻斷、手動譯文永遠可用 | ✅（真 adapter 待 7.2） |

### 狀態機（BQ-STATE）
| 狀態流轉 | 一致 | 非法轉換防護 | 稽核 | 狀態 |
|---------|------|-------------|------|------|
| ACTIVE→ARCHIVED→ACTIVE/EXPIRED | ✅ §3.1.3 | EXPIRED 不可逆＋`ERR_ARCHIVE_RESTORE_EXPIRED` | audit_log 三事件 | ✅ |

### 例外處理（BQ-EXCEPT）
| 場景 | 分類 | 狀態 |
|------|------|------|
| sidecar 三態（timeout/signal/exit≠0） | 碼分明、stderr tail 附診斷 | ✅（惟 I-002 的碼借用） |
| 檔案損毀 | pack/progress 專屬碼、零副作用 | ✅ |

## 前端業務實作品質審查（FQ-*）

| 檢查群 | 重點核對 | 狀態 |
|--------|----------|------|
| FQ-STATE | editor→practice 音節變更自動重建步驟（`ref.listen`）；lesson hydrate 單一 session 來源 | ✅ |
| FQ-RACE | 播放世代編號；分析/匯出按鈕置灰＋Domain 鎖雙保險；ai 譯文晚到丟棄 | ✅ |
| FQ-API | 17/17 錯誤碼有處理策略；未知碼有通用 fallback（`ErrorMessages.fromCode`） | ✅ |
| FQ-UX | 錯誤就地顯示不清空已填值（匯入字稿、匯出勾選保留）；歸檔二次確認；168h 倒數可見 | ✅ |
| FQ-AUTH | 不適用（單人本機無權限體系，matrix #15/16 已 APPROVED_NOT_APPLICABLE） | — |
| FQ-DATA | AI key obscure 輸入、送出即清空、UI 零副本；錄音不落地 | ✅ |

「使用驅動檢查」三項（第一眼內容／主任務步數／阻力點對策）：匯入 2 步、練習第 1 步即點即聽、到期清單置頂無逾期字樣——與 frontend-design 結論一致，未違反。

## 變更影響分析（IA-*）

| 面向 | 評估 | 狀態 |
|------|------|------|
| IA-SCOPE | 剩餘任務 2.1（sidecar 實體）→ 阻塞 9.1→9.2；7.2（真 adapter）獨立不阻塞主流程 | ✅ 依賴關係與 task-split §5 一致 |
| IA-COMPAT | `.abopack`/`.aboprogress` 均帶 schemaVersion=1；Drift onUpgrade 有 V1→V2 遷移 | ✅ |
| IA-ROLLBACK | 檔案原子寫入天然可回復；DB 交易；repo 有 main ruleset 防 force push | ✅ |
| IA-OBSERVE | 本機 log 與 audit_log 已覆蓋設定/歸檔事件；交付後監測留待 ops-monitoring 階段 | ⚠️ 待 ops-monitoring（流程內預期） |

## 六面向補充檢查

| 面向 | 結果 |
|------|------|
| 1 流程完整性 | ✅ 匯入→校正→練習→匯出→比對→SRS→課件/進度 round-trip 全鏈可走（e2e widget test 佐證）；release 旅程（9.1/9.2）未完成——已誠實列於 task-split，非斷鏈 |
| 2 階段銜接 | ✅ 需求↔設計↔任務↔程式↔測試逐層可追溯；無孤兒產物；`V1__create_all.sql`/`V2` 等被引用檔案皆存在，無幽靈引用。⚠️ 根目錄 12 份交接檔含 1 份「拷貝」重複檔且多數未進版控（見報告 1 建議） |
| 3 數據準確度 | ⚠️ I-001（matrix 19/20）；其餘抽核（11 音節全鏈、168h、±20ms、120s、15/5/2、4.689s benchmark）跨文件一致 |
| 4 定位一致性 | ✅ 「純本機單人、macOS v1 優先、無伺服器」全文件一致；Non-scope 零涉入 |
| 5 規範符合度 | ✅ 憲法 C1–C13 無違反；AI-Generate 全覆蓋；金鑰/個資掃描通過（pre-commit hook＋測試斷言＋本輪 grep 複核）；matrix 完整性通過（惟 I-001 數字） |
| 6 內文品質 | ⚠️ N-001（requirement 章內編號模板痕跡）；未發現公開露出文案錯字 |

## 修復清單（僅 blocking + important）

| 編號 | 檔案 | 問題 | 嚴重性 | 狀態 |
|------|------|------|--------|------|
| I-001 | guardrails/hard-limits-matrix.md:87 | 備忘「20 條 PARTIAL」應為 19 | important | 待修復（一行） |
| I-002 | errors.dart／whisper_transcriber.dart／demucs_separator.dart／analysis_pipeline.dart／practice_controller.dart＋兩份設計檔 | ERR_DECODE_FAILED 語意漂移，需新增專屬錯誤碼並三同步 | important | 待修復（小型變更防線→實作） |

---

*審查人：Claude（fullstack-code-review skill，全專案 QA 模式）。本報告不修改任何原始碼；修復由 fullstack-code-implementation 或人工執行後可觸發增量複審。三份 HTML 建議報告與 Codex agent 文件為本輪隨附交付物，見同目錄與 repo 根 `AGENTS.md`、`docs/codex/`。*
