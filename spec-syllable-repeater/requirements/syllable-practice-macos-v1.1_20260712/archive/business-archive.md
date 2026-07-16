// AI-Generate
# 業務歸檔（Business Archive）

## 1. 歸檔資訊

| 欄位 | 內容 |
|------|------|
| 需求目錄 | `spec-syllable-repeater/requirements/syllable-practice-macos-v1.1_20260712/` |
| 歸檔時間 | 2026-07-16 11:00 |
| 對照/回寫知識庫 | `spec-syllable-repeater/knowledge/business/business-overview.md` |

## 2. 業務背景與目標

### 2.1 背景

v1 讓使用者對「一句話」做音節疊加練習，但真實素材（歌曲、演講、影片台詞）是多句的。v1.1 補齊從「一整段音檔」到「一個可練習課件」的完整製課流程：先切段落、再進單句、可校正音節、可自由組合積木練習，最後整包封裝分享。同時把 v1 寫死的英文假設抽成「插座＋插頭」架構，為未來多語言鋪路。

### 2.2 目標與成功標準

| 目標 | 可驗證標準 |
|------|------------|
| 多句音檔可切段管理 | 段落標籤頁自動切段＋手動保留/捨棄；`.abolabel` v2 可存可載；指紋不符明確拒絕 |
| 音節切點可增減 | 刪切點合併、增切點一分為二（±10ms 零交越、50ms 下限）；金標準刪 1 切點→10 步、增 1 切點→12 步 |
| 練習內容可自由編排 | 積木/組塊/列三層；預設積木 1/1、列 3/1；0 列＝完整單句 1 單元、N 列＝N 單元 |
| 換 ASR 引擎不改核心 | TranscriberEngine/Syllabifier 雙 port；新引擎走 adapter＋五步上架（授權→故障注入→金標準回歸→註冊） |
| 語言不支援明確拒絕 | 查無切分器回 `ERR_LANGUAGE_UNSUPPORTED` 附支援清單；絕不默默用英文亂切 |
| 進度誠實呈現 | 所有進度由真實工作量推進；「已就緒」＝位元組＋格式＋時長全驗證 |
| 錄音最短生命週期 | 無任何錄音持久化；只留目前單元記憶體 PCM，五種時機清除 |
| 課程可整包分享 | `.abopack` v3 單檔含音訊＋可選標籤/課件/排列/進度；四層匯出來源不可混用 |

### 2.3 範圍外說明

v1 Non-scope 全數沿用（手機端、Windows、雲端、伺服器、TTS/AI 合成音訊、金流、Apple 簽章、Apple Silicon）。v1.1 另明確排除：跨 Lesson 積木拼接（Non-scope 12）、跨單元錄音暫存（r7 撤回）、非英文切分器交付（僅留架構）、線上 ASR（D7 僅本地）。

## 3. 業務角色與術語（v1.1 新增）

| 術語/角色 | 定義 |
|-----------|------|
| Segment（區段） | 段落標籤頁的一段時間範圍，三態：未標記／保留（kept）／捨棄（discarded）；只有 kept 送分析 |
| LabelSession | 一個音檔的標籤工作階段，dirty 狀態機保護未儲存變更 |
| `.abolabel` | 標籤註記檔（v2）：指紋＋語言＋分離開關＋區段清單；不含音訊 |
| 積木（PracticeBlock） | 自由排列最小單位＝一或多個音節的原音切片；設定 repeat 1–10、silence 0–20（0.5 級距） |
| 組塊（grouped block） | 多音節積木，同列長按堆疊而成，組內可排序、可拆組 |
| 列（PracticeRow） | 一行積木＝一個練習單元的內容；整列設定包住積木設定 |
| 單元（unit） | 練習頁可見的播放單位；0 列＝完整單句 1 單元、N 列＝N 單元（M12） |
| 單次參考（single-pass reference） | 錄音比對用的原音——只播單元來源一次，不含循環與靜音 |
| `.abopack` v3 | 複合課程封包：原始音訊必含＋標籤/單句課件/排列/最新進度可選 |
| 四層匯出 | 匯出時依「音訊來源→排列來源→單元範圍→設定覆寫」四層選擇；來源以指紋綁定不可混用 |
| 語言路由 | 每個課件/區段帶 language；ASR 與切分器雙表都支援才放行（M14） |
| 草稿身分（DraftLessonIdentity） | 分析成功即建立的課件 id，校正/排列/保存全程沿用，杜絕「同一課件兩個身分」 |

## 4. 業務流程

### 4.1 主流程（v1.1 五站式）

1. **切段**：匯入多句音檔→真實進度→自動切段→手動保留/捨棄→可存 `.abolabel`；同檔重開自動提示載入舊標籤。
2. **分析**：勾選區段送單句分析（或直接匯入單句）→就緒驗證→語言路由→音節時間軸。
3. **校正**：增刪切點、改字（保留原始辨識文字）、雙向高亮；總數變更即新步數基準。
4. **編排與練習**：一鍵生成或自由組合積木→練習頁單元化播放→四態顯示→錄音單次比對。
5. **封裝**：整包存 `.abopack` v3 或四層選擇匯出音檔。

### 4.2 分支與例外（v1.1 增量）

| 場景 | 業務規則 | 備註 |
|------|----------|------|
| 自動切段失敗 | 仍可手動標記，不阻斷製課 | ASR 降級＋警告 |
| 未儲存標籤換音檔 | 強制三選一，禁止靜默丟棄 | 系統不可接受清單 |
| 語言不支援 | 明確拒絕＋列支援清單，不給錯的結果 | M14 |
| 音節總數變更 | 舊排列標「過期」，使用者決定重生成或保留 | 不自動重排 |
| 排列被刪除 | 練習頁回落自動模式（完整單句） | M12 |
| 錄音比對失敗 | 仍可回放確認收音 | r7 使用者需求 |
| 封包版本過高 | 明確拒絕開啟，不錯讀 | v3 相容規則 |
| 匯出來源不一致 | 構造時即拒絕（指紋/課件/範圍任一不符） | 四層防線 |

## 5. 業務規則與約束（v1.1 新增 BR-011～BR-018）

| 規則編號 | 規則描述 | 來源 |
|----------|----------|------|
| BR-011 | 同一 Lesson 同一原音檔的多段切片可任意順序/次數串接播放匯出；分析軌（Demucs）只供辨識，永不進播放/匯出 | M1 補述 |
| BR-012 | 步數基準＝當時音節總數；金標準 11 僅為未編輯預設 | M11 |
| BR-013 | 自訂排列覆蓋顯示與播放，但自動模式演算法（M2）不可改；判定入口唯一 | M12 |
| BR-014 | 積木預設 1/1、列預設 3/1；列靜音基準只算擺放積木原始長度一次；列尾不留靜音、積木尾保留 | M3 r6 |
| BR-015 | ASR/切分器雙抽層；語言查無明確拒絕，禁默默 fallback | M13/M14 |
| BR-016 | 進度與就緒必須真實；假百分比＝功能錯誤 | M15 |
| BR-017 | 錄音零持久化：無 RecordingBuffer、temp 一律 finally 清、僅目前單元記憶體 PCM 五時機清除 | M10 r7 |
| BR-018 | 新 ASR 引擎/模型上架必經五步（adapter→授權→故障注入→金標準回歸→註冊） | M9 擴大＋#50 |

v1 BR-001～BR-010 全數沿用；BR-003（合併靜音）語意由 M3 r6 細化為三層規則。

## 6. 前後端職責邊界（業務視角，v1.1 增量）

### 6.1 後端（Domain/Infra）承擔

- 區段三態不變式、dirty 狀態機、`.abolabel` 全檔驗證與指紋比對。
- 切點增減的吸附/下限/最少音節防線；`originalText` 保留。
- 排列三層設定計算、唯一渲染路徑、單元判定唯一入口、跨 Lesson 拒絕。
- 語言路由 fail-closed；草稿身分唯一性。
- v3 封包欄位白名單與四層匯出指紋綁定。
- 真實進度事件（byte/階段）；錄音生命週期與受管暫存。

### 6.2 前端承擔

- 五站式流程的頁面銜接（pending Segment 單槽交接）。
- 就地錯誤提示、已填資料不因錯誤清空、dirty 三選一呈現。
- 拖曳/長按/點選插入等手勢，最終一律委派 Domain 驗證。
- hidden 模式全脈絡只留編號；stale banner 明示選擇。

### 6.3 禁止推諉清單（v1.1 增量）

- M12 單元判定不得在 UI/infra 重做，只能消費 `effectiveUnits` 結果。
- 排列渲染不得建第二套 renderer，只能走 `renderBlockRow`。
- 「已就緒」不得由 UI 自行判定，必須消費 reader 的 ready 事件。
- 錄音清除不得只靠頁面 dispose，Domain finally＋導覽監聽雙保險。

## 7. 需求追溯矩陣

| 需求編號 | 業務摘要 | 設計檔案位置 | 任務拆分位置 | 狀態 |
|----------|----------|--------------|--------------|------|
| REQ-10 | 視窗自適應 | frontend 功能點 9 | FP9.1-9.2 | 已完成＋真人驗收 |
| REQ-11 | 段落標籤與 `.abolabel` | backend 介面 20-23／frontend 功能點 10 | 3.1-3.6、FP10.1-10.4 | 已完成＋真人驗收 |
| REQ-12 | 單句分析模式 | backend 介面 35-36／frontend 功能點 11 | 9.2-9.3、FP11.1-11.3 | 已完成＋真人驗收 |
| REQ-13 | 切點增減校正 | backend 介面 24-26／frontend 功能點 12 | 4.1-4.4、FP12.1-12.3 | 已完成＋真人驗收 |
| REQ-14 | 雙向高亮與序號 | frontend 功能點 12 | FP17 | 已完成＋真人驗收 |
| REQ-15 | 自由編輯區 | backend 介面 27-29／frontend 功能點 13 | 5.1-5.7、FP13、S9-21/23 | 已完成＋真人驗收 |
| REQ-16 | 疊加區顯示自訂排列 | backend 介面 30／frontend 功能點 14 | 5.5-5.6、FP14 | 已完成＋真人驗收 |
| REQ-17 | ASR 抽換與多語言 | backend 介面 31 | 2.1-2.5、8.1 | 已完成（僅英文切分器，架構就緒） |
| REQ-18 | 錄音單次比對與效能 | backend 介面 32-33／frontend 功能點 15 | 9.4、10.6、S9-20 | 已完成＋真人驗收 |
| REQ-19 | 顯示模式切換 | backend 介面 34／frontend 功能點 16 | 7.1、FP16 | 已完成 |
| REQ-20 | 譯文編輯區搬移 | frontend 功能點 11 | FP11.3 | 已完成 |
| REQ-21 | `.abopack` v3 四層匯出 | backend 介面 37-38／frontend 功能點 17 | 10.1-10.10 | 已完成＋真人驗收 |

## 8. 專案記憶總清單（憲法 C8 專案級彙總）

### 8.1 通用層（`~/Karen_Memory/Dev_Memory/`，源自本專案、可跨專案調用）

| 檔案 | 一句摘要 |
|------|----------|
| `workflows/workflow_handoff_convention.md` | 交接檔命名流水號＋9 段結構規範 |
| `workflows/workflow_workspace_hygiene.md` | 交接檔/fixture/拷貝副本的工作區衛生規則 |
| `pitfalls/pitfall_錯誤碼借用_新增碼須三同步.md` | 錯誤碼不得就近借用，新增須三同步 |
| `pitfalls/pitfall_brew未信任tap靜默失敗.md` | brew 第三方 tap 未 trust 靜默拒裝；管線遮蔽 exit code |
| `wiki/chronicle_syllable-repeater.md` | 本專案開發歷程編年史（v1 需求成稿→v1.1 獨立複核） |

### 8.2 專案層（`spec-syllable-repeater/memory/`，共 62 卡，僅本專案調用）

- **決策卡 11 張**：demucs.cpp MIT 選型、hard-guardrails matrix、macOS 免簽章路線、sandbox UI demo 豁免、sidecar 路徑覆寫、v1.1 需求七決策、零交越 10ms 視窗、平台順序 macOS 優先、無伺服器簡化路徑、金標準 11 音節修正、開發工具鏈事實。
- **踩坑卡 13 張**：async expect future、check_guardrails 子字串 bug、Dart SDK sandbox cpuinfo、Finder Debug App cwd 黑畫面、gen_snapshot quarantine、record plugin lazy init、Riverpod3 override imports、Riverpod session null equality、v1.1 增量規格跨文件漂移、waveform canvas widget test、whisper Intel 需 16k CPU、widget test 真 async、錯誤碼借用（專案副本）。
- **流程卡 38 張**：涵蓋 AI service guardrails ports、alignment benchmark、analysis pipeline port/adapter、codex 協作接口、CT-09 授權 gate、demucs CLI 契約、Domain 純度防線、editor undo、export CT-03、FFmpeg LGPL staging、Flutter workspace 起手、library/lesson/pack 系列、git hook 兩層、GitHub Actions CI gate、just_audio fake backend、managed temp session、pipeline checkpoint resume、practice TDD、progress 系列、prosody overlay、QwenASR 借鏡、release sidecar gate、sidecar fetch/injection、v1.1 增量 matrix/設計介面、交接檔命名/啟動提示、切片對照 schema、四層匯出閉環、獨立複核審查輪等。

完整清單見 `spec-syllable-repeater/memory/` 目錄（一卡一檔）。

## 9. 開放問題（業務側）

| 編號 | 問題 | 待確認方 |
|------|------|----------|
| B-101 | v1.1 是否要重打對外散布用 unsigned zip（目前 `dist/` 為 v1 產物） | Karen |
| B-102 | 非英文切分器（如日文）何時排入——架構已就緒，僅缺 adapter＋字典 | Karen，未來版本 |
| B-103 | 舊版未管理 temp 298MB 一次性清理的批准時點 | Karen，關閉所有 App 後 |
| B-104 | `[監測規劃待補]`：ops-monitoring 輕量版監測規劃尚未產出 | 下一階段即辦 |
