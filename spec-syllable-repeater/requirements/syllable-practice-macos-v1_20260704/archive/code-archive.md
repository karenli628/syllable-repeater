// AI-Generate
# 程式碼與介面歸檔（Code Archive）

## 1. 歸檔資訊

| 欄位 | 內容 |
|------|------|
| 需求目錄 | `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/` |
| 歸檔時間 | 2026-07-11 23:30 |
| 涵蓋範圍 | macOS v1 全量本機 App：Domain / Infra / Flutter UI / release sidecar staging / x86_64 release build / unsigned zip |
| 關聯需求檔案 | `requirement/requirement.md` |
| 關聯設計檔案 | `design/backend-design.md` / `design/frontend-design.md` |
| 關聯任務拆分 | `task/task-split.md` |
| 知識庫專案路徑 | `spec-syllable-repeater/knowledge/code/syllable-repeater/` |

本輪歸檔在 `task-split.md` 2.1、7.2、9.1、9.2 全部完成，且 `bash scripts/ci_core_checks.sh` 通過後建立。由於本專案是純本機 macOS App，沒有 server deployment；本歸檔的發版驗收對象是 release `.app`、bundled sidecar、未簽章 zip 與 Core CI gate。

## 2. 需求與範圍摘要

### 2.1 需求概述

Syllable Repeater macOS v1 是單人、本機、無伺服器的語音模仿練習 App。使用者匯入英文音檔後，系統以 FFmpeg / whisper.cpp / demucs.cpp sidecar 產生音節時間軸，支援波形校正、句尾疊加練習、mp3 匯出、錄音比對、課件封裝、手動/AI 譯文與 SRS 進度。v1 發布路線為 Intel x86_64、未簽章 zip、使用者自行略過 Gatekeeper。

### 2.2 需求項對照

| 序號 | 需求項 | 模組 | 優先級 | 設計/任務拆分中的對應章節 |
|------|--------|------|--------|---------------------------|
| 1 | REQ-01 音檔匯入與自動音節對齊 | AnalysisPipeline / AlignmentEngine | P0 | backend-design 介面 1；task 3.1-3.5 |
| 2 | REQ-02 波形顯示與音節邊界校正 | Editor / AlignmentEngine | P0 | backend-design 介面 2；frontend FP3；task 3.6-3.7 |
| 3 | REQ-03 句尾疊加練習 | PracticeEngine / Practice UI | P0 | backend-design 介面 3-6；task 4.1-4.4 |
| 4 | REQ-04 練習音訊匯出 | PracticeExporter / Export UI | P0 | task 4.5-4.7；frontend FP5 |
| 5 | REQ-05 韻律分析與視覺化 | ProsodyAnalyzer / Editor overlay | P1 | task 5.1-5.2 |
| 6 | REQ-06 錄音比對與差異疊圖 | RecordingComparator / Practice UI | P1 | task 6.1-6.2 |
| 7 | REQ-07 課件封裝與譯文 | LessonPackEngine / AIService | P1 | task 7.1-7.2；frontend FP6/FP1/FP7 |
| 8 | REQ-08 練習進度與 SRS | ProgressEngine / Drift repository | P1 | task 7.3-7.6 |
| 9 | REQ-09 發布與跨平台架構約束 | Release / CI / Guardrails | P0 | task 2.1、8.1-8.4、9.1-9.2 |

## 3. 實作路徑（前後端）

### 3.1 後端實作路徑摘要

| 模組 | 主要實作 | 驗證重點 |
|------|----------|----------|
| Domain | immutable models、AlignmentEngine、PracticeEngine、ProsodyAnalyzer、RecordingComparator、LessonPackEngine、AIService、ProgressEngine | Domain 純 Dart、M1/M2/M3/M6/M7/M8/M10 規則測試 |
| Infra | SidecarRunner、FFmpeg/ffprobe/whisper/demucs adapters、Drift repository、AtomicFileIo、record/export adapters | sidecar crash/timeout 隔離、DB 結構防線、檔案原子寫入 |
| Release sidecars | `fetch_sidecar_artifacts.py`、`prepare_release_sidecars.py`、Xcode Release build phase | SHA-256 pinning、HTTPS TLS 預設驗證、拒絕 GPL/nonfree/static LGPL |
| AI adapters | `KeychainSecureStore`、`OpenAiResponsesClient` | API key 只進 Keychain；provider 失敗不洩 credential |
| Packaging | `make_release_zip.py`、`README-unsigned-macos.md` | release `.app` 必要檔 fail-closed 檢查、zip SHA-256 |

### 3.2 前端實作路徑摘要

| 功能點 | 實作位置 | 摘要 |
|--------|----------|------|
| App shell | `app/lib/main.dart`、`app/lib/shell/`、`app/lib/shared/navigation.dart` | ProviderScope、NavigationRail、sidecar provider bootstrap |
| 匯入分析 | `features/import_analysis/` | 檔案選取/拖放、階段進度、checkpoint 重試、demucs 未就緒提示 |
| 校正 | `features/editor/` | WaveformCanvas、音節列表、拖動邊界、undo |
| 練習/匯出 | `features/practice/`、`features/export/` | 原聲切片播放、錄音比較、mp3 匯出入口 |
| 課件/進度/設定 | `features/library/`、`features/progress/`、`features/pack_translate/` | `.abopack` / `.aboprogress`、SRS、Keychain AI key 設定 |

## 4. 介面與契約（以後端為權威）

### 4.1 介面清單

本專案沒有自家 HTTP Controller 或 REST API。對外/跨邊界契約如下：

| 介面說明 | HTTP | URL | Controller#方法 | 輸入參數摘要 | 輸出參數摘要 | 錯誤/冪等/交易要點 | 設計依據 |
|----------|------|-----|-----------------|--------------|--------------|-------------------|----------|
| OpenAI Responses 文字翻譯 | POST | `https://api.openai.com/v1/responses` | 無；`OpenAiResponsesClient.translate` | model、store=false、instructions、input；Authorization header | `output_text` 或 `output[].content[].text` | 未設 key / host blocked / timeout / provider failure 轉 `ERR_AI_*`；credential 不進 log/DB/pack | backend-design AIService；task 7.2 |
| FFmpeg decode/export | 無 | local process | `FfmpegDecoder` / `PracticeExporter` | 音檔或 stdin WAV | PCM 或 mp3 | timeout/crash/exit 非 0 映射 DomainException；release 僅 LGPL shared | backend-design §2.3、M4、M9 |
| whisper.cpp transcribe | 無 | local process | `WhisperCppTranscriber` | 16k mono WAV + small.en model | words/time offsets | Intel Mac 固定 `--no-gpu`；錯誤保留 checkpoint | task 3.2 |
| demucs.cpp separate | 無 | local process | `DemucsCppVocalSeparator` | model、input audio、out dir | `target_3_vocals.wav` | optional；缺件/失敗可降級原音 | task 3.8 |
| Drift progress repository | 無 | local SQLite | `DriftProgressRepository` | snapshots/groups/settings/audit | persisted rows | importProgress 交易套用；updatedAt newer-wins | task 7.3-7.6 |

### 4.2 與知識庫 `backend-interface` 的對照

| 本需求介面 | 分冊檔案/項目 | 變更型別 |
|------------|---------------|----------|
| OpenAI Responses API | `backend-interface.md` 遠端 HTTPS provider | 不變；本輪補 release 歸檔引用 |
| Sidecar CLI wrappers | `backend-interface.md` Sidecar CLI contracts | 不變；本輪補 release bundle 約束 |
| Riverpod provider entrypoints | `backend-interface.md` provider entrypoints | 不變 |
| Release packaging scripts | `backend-interface.md` 非業務入口/發布契約 | 新增知識庫行 |

### 4.3 interface-detail 追溯

本專案未生成 Controller-oriented `interface-detail/` 分冊，原因是架構為 Flutter 本機 App + Dart ports，沒有 REST Controller。介面契約集中維護於 `backend-interface.md`、backend design 介面 1-19，以及各 wrapper/controller 測試。

## 5. 資料與儲存

### 5.1 表結構/欄位變更摘要

本輪 release/archive 階段沒有新增資料表、欄位或索引。已完成 schema 為 6 張表：

| 表名 | 變更型別 | 說明 | 依據 |
|------|----------|------|------|
| `lesson_registry` | 不變 | 課件註冊與 content hash | task 1.2 / 7.4 |
| `practice_group` | 不變 | SRS 分組與歸檔狀態，無逾期/失敗欄位 | M7/M8 |
| `srs_state` | 不變 | 間隔 `[0,1,3,7,14,30]` | task 7.3 |
| `attempt` | 不變 | 只存 overlay/差異數值，不存音訊/路徑 | M10 |
| `app_settings` | 不變 | reminder 設定 key-value | task 7.6 |
| `audit_log` | 不變 | 本機自審操作紀錄，不存敏感資料 | task 8.4.2 |

### 5.2 與 `backend-database.md` 的對照

`backend-database.md` 已全量列出 6 張表與 ER 關係。本輪沒有 schema 變更，因此只在歸檔中記錄「無需更新」。資料防線仍由 `db_schema_test.dart` 與 Core CI 維持。

## 6. 前端程式碼與工程側

### 6.1 目錄/路由/元件變更摘要

| 型別 | 路徑或名稱 | 說明 | 依據 |
|------|------------|------|------|
| 修改 macOS release config | `app/macos/Runner/Configs/Release.xcconfig` | Release 固定 x86_64，避免產出 Apple Silicon/universal binary | AGENTS.md Non-scope；task 9.1 |
| 修改 entitlements | `app/macos/Runner/DebugProfile.entitlements` / `Release.entitlements` | `app-sandbox=false`，符合免簽章本機 sidecar 路線 | task 9.1 前置 |
| 修改 app infra | `app/lib/shared/infra/sidecar_paths.dart` | Debug/Profile 走 `.local-tools`，Release 走 bundled sidecar | task 2.1/9.1 |
| 新增 AI adapters | `keychain_secure_store.dart` / `openai_responses_client.dart` | 真 Keychain 與 OpenAI provider | task 7.2 |

### 6.2 `frontend-project.md` 增量說明

| 章節 | 是否更新 | 摘要 |
|------|----------|------|
| 業務功能模組 | 是 | `shared` 模組補 release bundled sidecar path 與 unsigned packaging 事實 |
| 介面呼叫清單 | 否 | 無新增 HTTP provider |
| 目錄結構說明 | 是 | `shared/infra` 補 Keychain/OpenAI/release sidecar adapters；macOS release config 補說明 |

## 7. 實際實作內容

### 7.1 新增檔案

| 路徑 | 用途 |
|------|------|
| `scripts/fetch_sidecar_artifacts.py` | sidecar acquisition gate：HTTPS、SHA-256、license/linking policy |
| `scripts/make_release_zip.py` | unsigned macOS zip 打包與 SHA-256 輸出 |
| `app/lib/shared/infra/keychain_secure_store.dart` | macOS Keychain SecureStore adapter |
| `app/lib/shared/infra/openai_responses_client.dart` | OpenAI Responses API adapter |
| `spec-syllable-repeater/requirements/.../release/README-unsigned-macos.md` | 使用者略過 Gatekeeper 與發版者打包說明 |
| `spec-syllable-repeater/knowledge/code/syllable-repeater/*.md` | code knowledge baseline |

### 7.2 修改檔案

| 路徑 | 修改摘要 | 原因 |
|------|----------|------|
| `scripts/prepare_release_sidecars.py` | 加強 FFmpeg shared LGPL、rpath/install name、必要檔檢查 | M9 發布防線 |
| `scripts/check_licenses.py` / `release/license-manifest.json` | 25 components license gate | CT-09 |
| `scripts/ci_core_checks.sh` | 納入 artifact/zip tests 與 release gates | 交付前同源 CI |
| `app/macos/Runner/Configs/Release.xcconfig` | 固定 `ARCHS=x86_64` / `ONLY_ACTIVE_ARCH=YES` | v1 Intel release scope |
| `task/task-split.md` / `task/execution-log.md` / `release/release-checklist.md` | 更新 2.1、7.2、9.1、9.2 完成與驗證證據 | 三同步與交接 |
| `.gitignore` | 新增 `dist/` | release artifact 本機保留、不進版控 |

## 8. 驗證與發版證據

| 項目 | 結果 |
|------|------|
| `flutter pub get` | 通過 |
| `python3 scripts/fetch_sidecar_artifacts.py --inventory-only` | 通過，所有 release sidecar artifacts 存在 |
| `python3 scripts/fetch_sidecar_artifacts.py --run-prepare-dry-run` / `--run-prepare` | 通過 |
| `flutter build macos --release --no-pub` | 通過，產出 x86_64 `.app` 634MB |
| bundled ffmpeg/ffprobe/demucs `otool -L` | 通過，FFmpeg 為 dynamic shared，demucs 只連系統 framework/lib |
| `python3 scripts/make_release_zip.py` | 通過，zip 524MB |
| zip SHA-256 | `38de745c051c7d19f11c254fe0406055979dbca7c4e6c07ef4474f2f670db8a2` |
| `bash scripts/ci_core_checks.sh` | 通過：Python 22 tests、domain 82、infra 69+2 skips、app 67+1 skip、analyze no issues |

## 9. 開放問題（實作側）

| 編號 | 問題 | 影響 | 狀態 |
|------|------|------|------|
| C-001 | 尚未由使用者在解壓後實際執行 `xattr -cr` 或右鍵開啟，跑完整 REQ-01→08 GUI smoke | AT-09-03 的使用者端體驗尚待最終驗收 | release artifact 已可供 smoke；不阻擋本機 build/archive |
| C-002 | FFmpeg `.asc` 因本機無 `gpg` 未做 PGP 驗章 | 供正式對外散布時可提高供應鏈信心 | SHA-256 pinning、source build、license gate 已通過；有 `gpg` 環境再補 |
| C-003 | `dist/` 與 sidecar/model 實體不進版控 | 新機接手須重建或重跑 acquisition/staging | 預期設計；manifest、scripts、README 已進版控 |

## 10. 知識庫融合檢查

| 檢查項 | 目標檔案 | 檢查結果 |
|--------|----------|----------|
| 應用層知識已融合 | `knowledge/application/application-overview.md` | 已新建 |
| 業務層知識已融合 | `knowledge/business/business-overview.md` | 已新建 |
| 前端專案檔案已融合 | `frontend-project.md` | 已更新 release/infra 事實 |
| 後端專案檔案已融合 | `backend-project.md` | 已更新 release/packaging 流程 |
| 介面清單已融合 | `backend-interface.md` | 已更新 release packaging contracts |
| 資料模型已融合 | `backend-database.md` | 本期無 schema 變更，無需更新 |
| 外部依賴已融合 | `backend-external-dependency.md` | 已更新 release sidecar/source/linking 約束 |
