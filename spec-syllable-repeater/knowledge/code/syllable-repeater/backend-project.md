// AI-Generate
# backend-project

## 1 專案目的

Syllable Repeater 的後端視角是本機領域服務與基礎設施 adapter：在不啟動伺服器的情況下，完成段落切段標籤（v1.1）、音訊解碼/辨識/音節對齊、切點增減校正（v1.1）、自由排列與單元渲染（v1.1）、跟讀渲染、錄音單次比對、課件封裝（`.abopack` v1/v2/v3）、SRS 進度與可選 AI 翻譯。核心守則是音訊播放/匯出必須逐 sample 來自原始 PCM 切片（分析軌只供辨識）、Domain 維持純 Dart、語言路由 fail-closed、進度誠實呈現、錄音零持久化。

## 2 專案目錄結構

### 2.1 分層歸類

| 層級 | 實際目錄/檔案 | 說明 |
|---|---|---|
| 入口層 | `app/lib/main.dart`、`app/lib/features/**` Riverpod controllers/providers | Flutter UI 與 workflow 入口，不是 HTTP Controller |
| 業務邏輯編排層 | `app/lib/features/*/*_controller.dart`、`app/lib/shared/infra/infra_analysis_runner.dart` | UI flow orchestration、provider 接線、analysis runner 組裝 |
| 核心領域服務層 | `packages/domain/lib/src/**` | 純 Dart models、engines、ports、business rules |
| 外部依賴層 | `packages/infra/lib/src/sidecar/**`、`app/lib/shared/infra/keychain_secure_store.dart`、`openai_responses_client.dart` | sidecar、Keychain、HTTPS provider adapter |
| 資料層 | `packages/infra/lib/src/db/**`、`packages/infra/lib/db/schema/**` | Drift/SQLite schema 與 repository |
| 發布層 | `scripts/fetch_sidecar_artifacts.py`、`scripts/prepare_release_sidecars.py`、`scripts/make_release_zip.py`、`app/macos/Runner/Scripts/copy_release_sidecars.sh` | release sidecar acquisition/staging、x86_64 `.app`、unsigned zip |

### 2.3 程式碼目錄結構樹

```text
syllable repeater/
├── pubspec.yaml                       # Dart workspace: app/domain/infra
├── app/
│   └── lib/
│       ├── main.dart                  # Flutter app + sidecar provider bootstrap
│       ├── shell/                     # NavigationRail shell
│       ├── features/                  # UI workflow entrypoints/controllers
│       └── shared/infra/              # app-layer infra adapters/providers
├── packages/
│   ├── domain/
│   │   └── lib/
│   │       ├── domain.dart            # public exports
│   │       └── src/
│   │           ├── ai/                # AIService guardrails
│   │           ├── alignment/         # alignment、切點增減、EnglishSyllabifier、SyllabifierRegistry（v1.1）
│   │           ├── analysis/          # AnalysisPipeline、TranscriberRegistry（v1.1）、prosody、peaks
│   │           ├── labeling/          # LabelSession、SegmentEngine（v1.1）
│   │           ├── model/             # immutable models（含 Segment/Arrangement/Units/CourseBundle/ExportPlan/DraftLessonIdentity，v1.1）
│   │           ├── pack/              # LessonPackEngine(v2)、LabelPackEngine、CourseBundleEngine(v3)（v1.1）
│   │           ├── ports/             # side-effect contracts（＋Transcriber/Syllabifier/LabelRegistry/Settings/AudioImportReader，v1.1）
│   │           ├── practice/          # PracticeEngine（＋arrangement/units 渲染）/export WAV
│   │           ├── progress/          # ProgressEngine/SRS/archive（＋transcriptDisplayModes）
│   │           └── recording/         # RecordingComparator（isolate、限點）
│   └── infra/
│       └── lib/
│           ├── infra.dart             # infra exports
│           ├── db/schema/             # DDL truth snapshots（V1-V3）
│           └── src/
│               ├── analysis/          # analysis adapters/cache、DartIoAudioImportReader（v1.1）
│               ├── db/                # Drift database/repository（＋label_registry/settings adapters，v1.1）
│               ├── practice/          # recording/export adapters
│               ├── sidecar/           # FFmpeg/whisper/demucs wrappers（whisper segment、demucs stereo，v1.1）
│               └── managed_temp_session.dart  # lease 鎖受管暫存（v1.1）
└── scripts/                           # release/license/guardrail gates
```

## 3 模組劃分

### 3.0 模組依賴圖

```mermaid
graph TB
    App[app Flutter UI]
    Domain[packages/domain pure Dart]
    Infra[packages/infra adapters]
    Sidecars[FFmpeg/whisper/demucs local sidecars]
    SQLite[SQLite/Drift]
    Keychain[macOS Keychain]
    OpenAI[OpenAI Responses API]

    App --> Domain
    App --> Infra
    Infra --> Domain
    Infra --> Sidecars
    Infra --> SQLite
    App --> Keychain
    App --> OpenAI
```

### 3.1 核心業務流程

#### 業務流程 1: 匯入音檔與音節對齊

- **輸入**: 使用者選取的音檔路徑、可選 transcript、可選 separateVocals。
- **處理**: FFmpeg decode → 可選 demucs 分離 → whisper.cpp transcription → `AlignmentEngine` syllabify → waveform peaks。
- **輸出**: `AlignmentResult`、`Pcm`、`WaveformPeak` list。
- **例外處理**: sidecar timeout/crash/exit 非 0 轉 DomainException；pipeline checkpoint 支援重試。

```mermaid
sequenceDiagram
    participant UI as AnalysisController
    participant Runner as InfraAnalysisRunner
    participant Pipeline as AnalysisPipeline
    participant FFmpeg as FfmpegDecoder
    participant Whisper as WhisperCppTranscriber
    participant Align as AlignmentEngine
    UI->>Runner: run ImportRequest
    Runner->>Pipeline: analyze
    Pipeline->>FFmpeg: decode audio
    Pipeline->>Whisper: transcribe 16k wav
    Pipeline->>Align: align words to syllables
    Align-->>Pipeline: AlignmentResult
    Pipeline-->>UI: done event
```

#### 業務流程 2: 句尾疊加練習與匯出

- **輸入**: `AlignmentResult.syllables`、原始 `Pcm`、repeatN、export mode。
- **處理**: `PracticeEngine.buildSteps` 依 M2 建 steps；`renderStep` 只切原始 PCM；export 以 FFmpeg 轉 mp3。
- **輸出**: 播放用 WAV 暫存或 mp3 export。
- **例外處理**: repeatN 越界、source range 超界、sidecar export 失敗皆回 DomainException/錯誤呈現。

```mermaid
flowchart LR
    A[Syllables + PCM] --> B[PracticeEngine.buildSteps]
    B --> C[PracticeEngine.renderStep]
    C --> D{播放或匯出}
    D -->|播放| E[PracticePlayer 暫存 WAV]
    D -->|匯出| F[PracticeExporter FFmpeg mp3]
```

#### 業務流程 3: SRS 進度、封存與同步匯入

- **輸入**: practice group、attempt、settings、imported snapshot。
- **處理**: `ProgressEngine` 套用 interval `[0,1,3,7,14,30]`、updatedAt newer-wins、archive 168 小時規則。
- **輸出**: Drift repository 中的 lesson/practice_group/srs_state/attempt/settings/audit_log。
- **例外處理**: EXPIRED 不可逆；跨日零懲罰；schema 不含逾期/失敗欄位。

```mermaid
sequenceDiagram
    participant UI as Progress UI
    participant Engine as ProgressEngine
    participant Repo as DriftProgressRepository
    UI->>Engine: update group/SRS/archive
    Engine->>Repo: save snapshot parts
    Repo->>Repo: upsert by updatedAt
    Repo-->>UI: persisted state
```

#### 業務流程 4: AI credential 與翻譯

- **輸入**: 使用者 API key、文字、目標語言。
- **處理**: `AIService.configure` 寫 Keychain 並記 audit；`translate` 檢查 credential、HTTPS allowlist、rate limit、prompt injection token；`OpenAiResponsesClient` 呼叫 provider。
- **輸出**: `Translation(source=ai)`；manual translation 仍可覆蓋。
- **例外處理**: 未設 key、provider failure、host blocked、timeout 皆轉 DomainException，不洩 credential。

```mermaid
flowchart LR
    A[API key] --> B[KeychainSecureStore]
    B --> C[AIService]
    D[Text + targetLang] --> C
    C --> E{guardrails pass?}
    E -->|是| F[OpenAiResponsesClient]
    E -->|否| G[ERR_AI_CALL_FAILED]
    F --> H[Translation ai]
```

#### 業務流程 5: release sidecar staging 與 unsigned macOS 打包

- **輸入**: `release/sidecar-artifacts.json`、本機 release-safe sidecar/model artifacts、Flutter macOS project。
- **處理**: `fetch_sidecar_artifacts.py` 檢查 HTTPS/SHA-256/license/linking policy；`prepare_release_sidecars.py` 檢查 CT-09、FFmpeg LGPL shared、Mach-O 依賴並產 staging；Release build phase 檢查必要 sidecar；`flutter build macos --release --no-pub` 產 x86_64 `.app`；`make_release_zip.py` 產 unsigned zip 與 SHA-256。
- **輸出**: `dist/SyllableRepeater-macos-x86_64-unsigned.zip` 與 `.sha256`；release artifact 不進版控。
- **例外處理**: 缺 artifact、GPL/nonfree/static LGPL、TLS/CERT 降級、非 HTTPS URL、缺 SHA-256 或 bundle 缺必要檔，一律 fail-closed。

### 3.2 業務模組

| 模組 | 功能 | 核心實體/資料 | 主要介面 |
|---|---|---|---|
| Labeling（v1.1） | 段落切段、三態標記、`.abolabel` v2 | `Segment`、`LabelSession`、`LabelOpenResult/Warning/Progress` | `SegmentEngine.openAudio`、`LabelPackEngine.writeLabel/readLabel` |
| Registry（v1.1） | ASR/切分器語言路由（fail-closed） | `TranscriberEngine`/`Syllabifier` ports | `TranscriberRegistry/SyllabifierRegistry.resolve` |
| Analysis | 解碼、分離、轉寫、音節對齊（雙 Registry 路由；雙軌 PCM） | `ImportRequest`（language/sourceRange）、`AnalysisEvent`、`AnalysisAudioTracks`、`AlignmentResult` | `AnalysisPipeline.analyze` |
| Alignment | CMUdict + vowel fallback syllabify；切點增減/改字（v1.1） | `Word`、`Syllable`（originalText）、`TimeRange` | `AlignmentEngine.align/removeBoundary/insertBoundary/updateSyllableText` |
| Arrangement（v1.1） | 積木/組塊/列自由排列與單元判定 | `PracticeBlock/Row/Arrangement`、`PracticeUnits`、`DraftLessonIdentity` | `generateArrangement`、聚合操作、`renderBlockRow`、`effectiveUnits`、`renderSinglePassReference` |
| Practice | 疊加步驟與原始 PCM 渲染 | `PracticeStep`、`Pcm` | `PracticeEngine.buildSteps/renderStep/renderMergedExport/renderCustomExport` |
| Recording | 錄音單次比對（isolate、每圖 ≤1000 點） | `ComparisonResult`、`ProsodyPoint` | `RecordingComparator.compare` |
| Pack | `.abopack` v1/v2/v3、`.abolabel` v2、四層匯出 | `Lesson`（language/arrangement）、`CourseBundle`、`PracticeExportPlan` | `LessonPackEngine`、`CourseBundleEngine.writeV3/read`、`PracticeExportPlanner.build` |
| Progress | SRS、archive、settings、顯示偏好 | `ProgressSnapshot`（transcriptDisplayModes）、`PracticeGroup`、`SrsState` | `ProgressEngine`、`ProgressRepository`、`SettingsService` |
| Import Ready（v1.1） | 真實匯入就緒（M15） | `AudioImportProgress` | `AudioImportReader.readAndValidate` |
| AI | credential + translation | `AiProviderConfig`、`Translation` | `AIService.configure/translate` |
| Infra Sidecar | child process isolation | `SidecarResult` | `SidecarRunner.run` |
| Infra DB | Drift persistence | 7 張 SQLite 表（V3 增 label_registry） | `DriftProgressRepository`、`DriftLabelRegistryRepository`、`DriftSettingsService` |
| Infra Temp（v1.1） | lease 鎖受管暫存與清掃 | temp session dirs | `ManagedTempSession` |
| Release Gate | x86_64 sidecar 發布；新引擎五步上架 | `.app` bundled sidecar + zip | `fetch/prepare/make_release_zip` scripts＋`check_licenses.py`（source 必填） |

### 3.3 業務規則

- M1：播放/匯出音訊逐 sample 來自原始 PCM；禁止 TTS/生成/合成。v1.1 補述：同 Lesson 同原音的多段切片可任意順序/次數串接；`originalPcm`/`analysisPcm` 分欄，分析軌（Demucs）只供辨識。
- M2：步數等於音節數，第 n 步為句尾倒數 n 個音節，不做單字邊界吸附。
- M3（r6 細化）：積木預設 repeat 1/silence 1 倍（尾輪保留）；整列預設 3/1 倍（靜音基準只算擺放積木原始長度一次，尾輪不留）；多單元間隔＝前一已渲染單元 totalDurationMs。
- M5：Domain 純 Dart，不 import Flutter、infra、dart:io/ffi/html。
- M6：進度合併依 updatedAt 較新覆寫；contentHash 僅重置該課（仍只依原音＋音節，排列變更不重置）。
- M7：跨日零懲罰，schema 無逾期/失敗/懲罰欄位。
- M8：ARCHIVED 168 小時內可恢復，不含 168 小時；EXPIRED 不可逆。
- M9：release 僅允許 MIT/BSD/ISC/Apache-2.0/LGPL dynamic，禁止 GPL/AGPL/non-commercial；新 ASR 引擎/模型上架必經五步（adapter→授權→故障注入→金標準回歸→註冊）。
- M10（r7 定案）：API key 只進 Keychain；錄音零持久化——無 RecordingBuffer 類型/表/provider，temp 一律 finally 清除，僅目前單元最近一次 PCM 存 UI 記憶體（五時機清除）；DB/pack/progress/audit 不存音訊或路徑欄位。
- M11（v1.1）：步數基準＝編輯後當時音節總數；金標準 11 僅為未編輯預設。
- M12（v1.1）：排列覆蓋——0 列＝完整單句 1 單元、N 列＝N 單元；`effectiveUnits` 為唯一判定入口；自動模式演算法不可改。
- M13（v1.1）：ASR 與 Syllabifier 雙抽層 port；新引擎以 adapter 加入，不改 Domain。
- M14（v1.1）：每 Lesson/Segment 必帶 language；查無切分器明確拒絕附支援清單，禁默默英文 fallback。
- M15（v1.1）：進度與就緒必須由真實工作量/階段事件推進；「已就緒」＝位元組＋格式＋時長全驗證；禁假百分比。
