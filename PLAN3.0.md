# PLAN 3.0 — 端到端語音/歌曲/台詞模仿練習系統：架構設計與工程哲學

> 取代 PLAN2.0 的「分析建議」性質，定位為**可直接照著一步步落實的架構與工程規格**。
> 所有規格已與用戶逐項確認。撰寫原則：化繁為簡、深模組、TDD、垂直切片穩健推進。
> 本版整合 Codex 審查（Python 體積、MFA 外掛化、S1 風險、Practice Group、SRS 細節）與「原聲不可替換」最高約束。

---

## 0. 工程哲學（不可妥協的地基）

這六項是地基，不是儀式。沒有它們，「自用 → 商用」的轉換會逼你重寫。

1. **To-PRD**：每個大功能先寫一頁 PRD（問題 / 方案 / 使用者故事 / 實作決策 / 測試決策 / out of scope）。
2. **DDD + 共享詞彙**：`CONTEXT.md` 固定領域術語，全程式碼一致使用，杜絕「音節 vs 單字」混淆變 bug。
3. **ADR**：每個有長期後果的決策寫一則架構決策紀錄，含「為什麼」與「被否決的選項」。
4. **Deep Modules**：核心複雜度收進模組內部，對外只露窄而穩定的介面。介面醜 = 重新設計，不是繞過。
5. **TDD**：red → green → refactor。只測公開行為，不測內部實作。演算法模組尤其嚴格。
6. **To-Issues**：每個任務切成「能獨立交付的垂直切片」，每片可單獨 demo。不做半成品橫切。

**化繁為簡準則**：三行相似程式碼勝過一個過早抽象。不為假想未來需求設計。錯誤處理只在系統邊界（使用者輸入、sidecar、檔案 IO），內部模組互信。

---

## 0.1 最高約束：原聲不可替換（凌駕一切）

> 此約束優先級高於任何精度、效能、功能考量。違反它的設計一律否決。

- 每一個 `PracticeStep` 播放/匯出的音訊，**必須是從原始音檔解碼後的 PCM 上，按時間區間切片再串接的原說話者波形，逐 sample 來自原檔**。
- **禁止**：TTS、音高重算、音節替換、跨來源拼接、AI 合成示範音、任何「重新生成」音訊的路徑。
- 原音 timeline 是**唯一真相來源（single source of truth）**。`She has excellent communication skills` 裡 `communication` 的 `ca` 怎麼念，疊加到第 N 步那個 `ca` 就必須是同一段原始錄音剪出來的。
- 切點誤差只影響「剪得乾不乾淨」，**不影響「是不是原聲」**——因為全程只有剪刀，沒有合成。
- 優先級明示：**「是不是原聲」＞「切點準不準」**。切點歪幾十 ms 可接受（仍是原聲連續片段）；發音被替換絕不接受。
- 分析模組（ProsodyAnalyzer / AIService）**只讀音訊，永不生成音訊**。
- 切片收尾：切點吸附最近的零交越點（zero-crossing），或加 ~10ms micro-fade 去接點爆音——此處理**不改變發音內容**。

---

## 1. 領域共享詞彙（CONTEXT.md 種子）

| 術語 | 定義 |
|---|---|
| `Lesson` | 一個音檔經製作後的完整課件（= 一個 `.abopack`） |
| `Word` | 原文的一個單字（she / has / excellent / communication / skills） |
| `Syllable` | 音節，疊加練習的最小單位（ex / cel / lent 各一個） |
| `Phone` | 音素，whisper/對齊中間產物，比音節更細 |
| `PracticeStep` | 句尾疊加的一步（第 n 步 = 從句尾數第 n 個音節 → 句尾） |
| `PracticeGroup` | **進度 / SRS 結算的最小單位**，限定在單一 Lesson 內。跨 Lesson 用 Practice Session 表示 |
| `Attempt` | 使用者對某 `PracticeStep` 的一次錄音嘗試 |
| `Prosody` | 韻律分析結果：rhythm / intensity / stress / pitch contour |
| `Pack` | `.abopack` 課件檔（zip + JSON + 音訊） |
| `Progress` | `.aboprogress` 個人進度檔（zip + JSON） |

> 鐵則一：音節一律 `Syllable`，單字一律 `Word`，不混用。
> 鐵則二：疊加單位是 `Syllable`，**純音節逐個疊加，不做單字邊界吸附**。
> 鐵則三：所有練習音訊來自原音切片，**不得生成**（見 §0.1）。

---

## 2. 系統架構總覽

```
┌─────────────────────── 桌面製作端 (Windows v1, macOS 後) ───────────────────────┐
│  UI (Flutter/Dart) — CustomPainter 畫波形                                        │
│    │                                                                            │
│  Domain Layer (純 Dart，可單元測試，不依賴 sidecar/UI)                            │
│    ├─ LessonPackEngine     讀寫 .abopack                                         │
│    ├─ AnalysisPipeline     編排：解碼→分離→對齊→音節→韻律                         │
│    ├─ AlignmentEngine      whisper.cpp word ts + CMUdict + 等比例切 + 手動校正    │
│    ├─ ProsodyAnalyzer      自研輕量 DSP(rhythm/intensity/stress) + YIN(pitch)    │
│    ├─ PracticeEngine       句尾疊加：原音切片+串接（絕不生成）+ 匯出指令          │
│    ├─ RecordingComparator  原音切片 vs 使用者錄音，DTW，產 rhythm/intonation     │
│    ├─ ProgressEngine       .aboprogress upsert / SRS / 提醒 / 字典歸檔            │
│    └─ AIService            使用者自帶 key，翻譯/潤稿/建議（可選，不生成音訊）      │
│    │                                                                            │
│  Sidecar Layer (Process.start，崩潰不拖垮 App，全 C++/原生 免 Python)             │
│    └─ FFmpeg(LGPL) / whisper.cpp / demucs.cpp                                    │
│  可選外掛(使用者另下載，不進主程式)：MFA、CREPE、WORLD                            │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │  .abopack / .aboprogress
                                    ▼
┌─────────────────────── 手機練習端 (Android/iOS, Phase 2) ───────────────────────┐
│  UI → Domain (LessonPackEngine 讀 / PracticeEngine / ProgressEngine)             │
│  不跑任何 AI / sidecar；只播放、疊加(切片)、錄音比對、SRS、進度匯出               │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**架構鐵則：**
- Domain Layer 純 Dart，不 import sidecar/UI，100% 可單元測試 → TDD 施力點。
- Sidecar 全 `Process.start()`，全部 **C++/原生、零 Python**（綠色小體積目標）；崩潰只回傳失敗，App 絕不崩。
- 重 Python 工具（MFA / CREPE / WORLD）一律**外掛化**，使用者另下載，不進 v1 主程式。
- 手機端 Domain 與桌面共用同一份 Dart code，差別只在「不註冊 sidecar」。
- AI key 由使用者輸入，`flutter_secure_storage` 本機加密；自用與商用同一套碼，營運方不碰金流。

---

## 3. Deep Modules 規格

每個模組：對外窄介面 + 內部吃掉複雜度。TDD 測這層，不測內部。

### 3.1 AlignmentEngine（主路徑改為輕量、免 Python）
```
align(audioPath, transcript?) -> AlignmentResult
  AlignmentResult { words[], syllables[], source, confidence, needsReview }
  Syllable { text, startMs, endMs, wordIndex }
```
- **主路徑（v1，免 Python）**：`whisper.cpp` 產 word-level timestamp → CMUdict 查英文音節數 → 字內**等比例切音節** → 使用者波形手動校正。
- 單音節單字（she/has/skills）：whisper.cpp 邊界直接用，準。
- 多音節單字（ex·cel·lent、com·mu·ni·ca·tion）：等比例切是估計值，標 `needsReview`，使用者可手動拖。
- **MFA 降為桌面可選外掛**（使用者另下載，高精度進階路徑），非 v1 內建。

### 3.2 ProsodyAnalyzer（自研輕量 DSP，免 librosa/CREPE）
```
analyze(audioPath, syllables) -> Prosody
  Prosody { rhythm, intensity[], stress[], pitchContour?, pitchAvailable }
```
- `rhythm`：音節時長比例（用 syllables 時間戳，自寫）
- `intensity`：RMS 能量曲線（自寫 DSP）
- 停頓：低能量區間偵測（自寫）
- `stress`：音節能量 + 時長 加權（自寫）
- `pitchContour`：v1 用 **YIN / autocorrelation**（自寫或小型 permissive lib）；v1.5 評估 **WORLD C++（modified BSD）**；CREPE 降為可選外掛模型包。抽不到時 `pitchAvailable=false`，rhythm 仍正常回傳。

### 3.3 PracticeEngine（核心演算法，最嚴格 TDD，受 §0.1 約束）
```
buildSteps(syllables, repeatN) -> PracticeStep[]
  PracticeStep { index, syllables[], sourceRanges[], totalDurationMs }
renderStep(step, originalPcm) -> pcm   // 只切片+串接，絕不生成
```
**演算法（純音節、不吸附）：**
- 起點：句尾最後一個音節；第 n 步 = 從句尾數第 n 個音節 → 句尾全部音節
- 步驟總數 = 音節總數；每步音訊 = 對應音節片段重複 `repeatN` 次

`She has excellent communication skills`（15 音節 = she+has+ex·cel·lent+com·mu·ni·ca·tion+skills）→ **14 切點 → 15 步**：

| step | 內容 |
|---|---|
| 1 | skills |
| 2 | tion skills |
| 3 | ca tion skills |
| … | （逐音節往前）… |
| 15 | she has ex cel lent com mu ni ca tion skills |

`thank you very much`（5 音節）→ much / ry much / ve ry much / you ve ry much / thank you ve ry much。

**§0.1 強制**：`sourceRanges[]` 只存「原音檔上的 [startMs,endMs]」；`renderStep` 只能 copy 原 PCM 區間 + 串接 + 零交越/micro-fade 收尾。**任何生成路徑視為 bug。**

**匯出：**
```
exportStep(step) -> mp3                       // 單步
exportMerged(selectedSteps[]) -> mp3          // 勾選子集合併
  段落間靜音長度 = 前一步 totalDurationMs（= 片段長 × repeatN）
```
範例（N=3，much 單次 0.4s）：`[much×3]=1.2s → 靜音1.2s → [ry much×3]=1.8s → 靜音1.8s → [ve ry much×3] → …`

### 3.4 RecordingComparator（DTW）
```
compare(userRecording, syllables, step) -> ComparisonResult
  // 用 step 音節時間戳，從『整句原音』切出對應片段
  ComparisonResult { rhythmDelta, intonationDelta, overlayData, score? }
```
- 比對基準：使用者該步錄音 vs 從整句原音切出的對應片段
- 重點：rhythm + intonation（用戶最在乎）
- `overlayData`：供 UI 畫雙波形/音高疊圖，差異區段標色
- 錄音：預設用完即刪；`overlayData` + 參數一律保留

### 3.5 ProgressEngine（含 SRS / 提醒 / 跨日 / 封存，補回 PLAN1.0 定案）
```
upsert(local, incoming)               // 依 updatedAt 合併，較新覆寫
contentHashChanged(lesson) -> bool    // Lesson 變更只重置該課，不波及整 Course
nextDue(group) -> DateTime            // SRS 排程
```
- **結算單位 = `PracticeGroup`**，限定單一 Lesson 內；同步鍵 `Profile + Course + Lesson + Group`
- **提醒優先序**：① 每次練習分鐘數 → ② 每次未達標數上限 → ③ 每日練習次數
- **預設複習間隔**：第 0 / 1 / 3 / 7 / 14 / 30 天
- **難度三檔**：困難＝縮短間隔、最高優先；普通＝進入下一段；輕鬆＝延長間隔或最低頻
- **跨日未完成**：不催、不記失敗、不懲罰、不累積債；該次靜默作廢，但 `PracticeGroup` 仍可在未來被叫出
- **字典歸檔**：歸檔不滿 7 日可恢復；恢復後可重新排程；不影響本機課件與進度

### 3.6 LessonPackEngine
```
write(lesson) -> .abopack   // zip + JSON + 音訊
read(path) -> Lesson
```
- `.abopack` **不做**授權/防盜欄位（音檔來源由使用者自負責）
- 每筆 AI/分析結果存 `source / modelName / analyzerVersion / confidence / needsReview`

### 3.7 AIService（可選，不生成音訊）
```
configure(userApiKey)                 // flutter_secure_storage 加密本機
translate / annotate / suggestGroups
```
未設 key → 功能停用，不阻斷主流程（手動打字譯文永遠可用）。**不得用於生成或示範音訊**（§0.1）。

---

## 4. 資料格式

**`.abopack`**（zip + JSON + 音訊）：manifest、原音、（demucs.cpp 分離的）vocals/instrumental、waveform peaks、words、syllables、translations、prosody、practiceSteps 設定、`passive_practice.m4a`。
**`.aboprogress`**（zip + JSON）：熟練度、SRS 狀態、PracticeGroup 設定、`attempts[]`（只存參數與 overlay 快照，**不存錄音**）、字典歸檔狀態。

同步：鍵 `Profile + Course + Lesson + Group`；`updatedAt` 較新覆寫；`Content Hash` 變更只重置該 Lesson。

---

## 5. 落實順序（垂直切片，每片可獨立 demo）

> v1 第一刀 = **辨識管線先跨通**。先有可靠音節邊界，疊加才有意義。
> S1 內部分階降風險（Codex 第1點）：里程碑不必等分離搞定，但分離仍在 v1 範圍。

| Slice | 內容 | 完成定義（demo 標準） |
|---|---|---|
| **S0** | PRD + CONTEXT.md + ADR 骨架 + sidecar 接線（FFmpeg LGPL，驗證崩潰隔離） | `Process.start` FFmpeg 取得時長，sidecar 崩潰 App 不崩 |
| **S1a（v1 第一刀）** | 匯入 → FFmpeg 解碼 → whisper.cpp word ts → CMUdict 切音節 → 波形+音節邊界顯示 | 匯入 `She has excellent communication skills`，列出 15 音節與時間戳 |
| **S1b** | 波形上手動校正音節邊界（多音節字微調） | 拖動 `com·mu·ni·ca·tion` 內部邊界並存回 |
| **S1c** | demucs.cpp 人聲分離接入（v1 範圍，排在管線後段） | 有背景音樂的音檔分離出 vocals，邊界仍正確 |
| **S2** | PracticeEngine 疊加序列 + 單步播放（原音切片，§0.1） | 逐步播放 skills / tion skills / … ×N，音色全為原聲 |
| **S3** | 單步匯出 + 合併匯出（靜音=前步總時長） | 匯出第 3 步 mp3；勾選全步合併，靜音長度正確 |
| **S4** | ProsodyAnalyzer 自研 DSP（rhythm/intensity/stress；YIN pitch 可降級） | 顯示波形 + 音高曲線 + 音節邊界線 |
| **S5** | RecordingComparator + 視覺化疊圖 | 某步錄音 vs 原音切片，雙波形/音高疊圖、差異標色 |
| **S6** | LessonPackEngine 寫 `.abopack` + 譯文（自動 + 手動覆蓋） | 匯出課件，含手動打字譯文路徑 |
| **S7（Phase 2）** | 手機端：讀 `.abopack`、疊加、錄音比對、SRS、`.aboprogress` | 手機完成一輪練習並匯出進度 |
| **S8（Phase 3）** | macOS sidecar 重編 + 簽章/notarization | macOS 完整製作流程通過 |

演算法片（S2/S3/S5）先寫測試。每片起手先寫該片 PRD。

---

## 6. 測試策略（TDD，只測公開行為）

| 模組 | 必測公開行為 |
|---|---|
| AlignmentEngine | 有字稿走 whisper.cpp+CMUdict；多音節字標 needsReview；15 音節邊界 |
| PracticeEngine | 15 音節 → 15 步；純音節不吸附；**renderStep 輸出逐 sample 等於原音切片串接（§0.1 回歸測試）**；合併靜音 = 前步總時長 |
| RecordingComparator | 依音節時間戳從整句切出正確片段；產 rhythm/intonation |
| ProsodyAnalyzer | YIN 失敗時 pitchAvailable=false 但 rhythm 仍回傳 |
| ProgressEngine | updatedAt upsert；Content Hash 變更只重置該 Lesson；跨日未完成不扣分；字典 7 日內可恢復 |
| Sidecar 邊界 | sidecar 崩潰 → 回傳失敗 + App 不崩 + 保留工作狀態 |

不測：UI 像素、sidecar 內部、private 方法。

---

## 7. 驗收（以 `She has excellent communication skills` 為金標準）

1. 匯入音檔，whisper.cpp + CMUdict → 15 音節，she/has/skills 邊界準，多音節字可手動校正
2. 譯文：自動翻譯 + 手動打字覆蓋兩路徑都通
3. 顯示波形 + 音高曲線 + 音節邊界線
4. 疊加 15 步，從 skills 起逐音節往前，每步重複 N 次
5. **§0.1 驗收：第 8 步播放的每個音節，逐 sample 等於原音對應區間（無任何合成）**
6. 單步匯出第 3 步可播 mp3；合併全步段落靜音 = 各步 ×N 總時長
7. 某步錄音 vs 原音切片，產出 rhythm + intonation 疊圖、差異標色
8. 全鏈零 Python 主程式、零 GPL（FFmpeg=LGPL build）；MFA/CREPE/WORLD 僅外掛

---

## 8. 技術選型與授權白名單

**v1 主程式（全 C++/原生，免 Python，小體積）：**

| 功能 | 方案 | 授權 |
|---|---|---|
| UI / App | Flutter + Dart | BSD |
| 音訊播放 | just_audio（必要時原生 adapter） | MIT |
| 波形顯示 | Flutter CustomPainter | BSD |
| 解碼/轉碼/匯出 | FFmpeg sidecar（**LGPL build**，不可 GPL build） | LGPL |
| 語音辨識草稿 | whisper.cpp sidecar | MIT |
| 人聲分離 | **demucs.cpp** sidecar（C++，免 Python；v1 就要） | MIT |
| 英文音節數 | CMUdict + 規則 | permissive |
| 節奏/重音/音量 | 自寫 RMS / duration / pause / energy | 自有 |
| 音高 | YIN / autocorrelation（v1）→ WORLD C++（v1.5 評估） | 自有 / mBSD |
| SRS/進度/封存 | Dart + SQLite/Drift | MIT |
| AI key 儲存 | flutter_secure_storage | MIT |

**授權白名單**：可用 MIT / BSD / ISC / Apache-2.0 / LGPL（須動態連結、可替換、授權告知，如 FFmpeg LGPL）。
**禁止內建閉源商用主程式**：GPL / AGPL / CC BY-NC / 研究用途限定模型。
**特別點名**：Praat = GPL（不可內建）；Essentia 開源版 = AGPL 且部分模型非商用（不可 v1 用）；CREPE 本身 MIT 但 TensorFlow 體積大（外掛化）；MFA 本身 MIT 但 Conda/Kaldi 重（外掛化）。

**體積約束**：桌面綠色免安裝版目標下，sidecar（whisper.cpp / demucs.cpp 模型）為主要體積來源；重 Python 工具（MFA / CREPE / WORLD）一律外掛化、使用者另下載，不進主程式。正式體積以 release build 為準。

**無未消除商用紅線**：GPL 已避開、Python 體積已外掛化、AI key 使用者自帶不碰金流、`.abopack` 不做防盜（來源使用者自負責）。
