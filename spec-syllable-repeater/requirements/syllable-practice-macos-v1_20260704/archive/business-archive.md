// AI-Generate
# 業務歸檔（Business Archive）

## 1. 歸檔資訊

| 欄位 | 內容 |
|------|------|
| 需求目錄 | `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/` |
| 歸檔時間 | 2026-07-11 23:30 |
| 對照/回寫知識庫 | `spec-syllable-repeater/knowledge/business/business-overview.md` |

## 2. 業務背景與目標

### 2.1 背景

使用者想練習英文語音、歌曲或台詞模仿，不是聽整句重複，而是從句尾最短音節開始逐步往前疊加。這要求系統能把一句話切成可信的音節時間軸，且播放/匯出的聲音必須是原始音檔本身，不能被 TTS、AI 生成或音高重算替換。

### 2.2 目標與成功標準

| 目標 | 可驗證標準 |
|------|------------|
| 快速從音檔得到可校正音節時間軸 | 金標準 `She has excellent communication skills` = 11 音節、10 切點、11 步 |
| 句尾疊加玩法正確 | 第 n 步為句尾倒數 n 個音節，不吸附單字邊界；第 2 步是 `tion skills` |
| 原聲練習與匯出 | `renderStep` 輸出逐 sample 來自原 PCM，僅允許零交越或 <=10ms micro-fade |
| 本機隱私與無伺服器 | API key 只進 Keychain，錄音比對後清理，DB/pack/log 無音訊/key |
| 授權可發布 | release bundle 零 GPL/AGPL/non-commercial/研究限定；FFmpeg 為 LGPL dynamic shared |
| 可交付 macOS v1 | x86_64 release `.app`、unsigned zip、Gatekeeper 說明與 Core CI 全綠 |

### 2.3 範圍外說明

手機端、Windows、批次匯入、雲端同步、伺服器、TTS/AI 合成音訊、商用金流、Apple 官方簽章/notarization、Apple Silicon/universal binary 皆為 v1 Non-scope。任何新增都必須先走變更防線，不能在實作中偷加。

## 3. 業務角色與術語

| 術語/角色 | 定義 |
|-----------|------|
| 學習者/製作者 | 本機 App 唯一使用者，持有音檔、字稿、錄音與可選 AI key |
| Lesson | 一個音檔製作後的完整課件，即 `.abopack` |
| Syllable | 音節，疊加練習最小單位 |
| PracticeStep | 第 n 步 = 從句尾數第 n 個音節到句尾 |
| PracticeGroup | 進度/SRS 結算最小單位 |
| Attempt | 一次錄音比對嘗試，只保留差異資料，不保留音訊 |
| Sidecar | FFmpeg / whisper.cpp / demucs.cpp 外部行程 |
| SRS | 間隔重複排程；跨日未練零懲罰 |
| 未簽章 release | v1 使用者自行略過 Gatekeeper 的 zip 發布方式 |

## 4. 業務流程

### 4.1 主流程

1. 匯入音檔與可選字稿，系統產出詞級與音節級時間戳。
2. 使用者在波形上校正多音節字內部切點，查無字或估計切分標示 `needsReview`。
3. 系統依音節建立句尾疊加步驟，讓使用者由短到長跟讀。
4. 使用者可播放、重複、錄音比對、查看節奏/音高差異。
5. 使用者可匯出單步或合併 mp3，合併靜音長度跟前一步時長一致。
6. 使用者可保存 `.abopack`、手動輸入譯文或使用自帶 AI key 做可選翻譯。
7. 使用者可匯出/匯入 `.aboprogress`，系統依 updatedAt 合併進度並維持 SRS。
8. v1 發布以未簽章 zip 提供，使用者解壓後略過 Gatekeeper 開啟。

### 4.2 分支與例外

| 場景 | 業務規則 | 備註 |
|------|----------|------|
| sidecar 失敗 | 不讓 App 崩潰，保留已完成階段，可重試 | M4 |
| demucs 不可用 | 降級原音仍可分析 | 可用性優先，不破壞 M1 |
| AI provider 不可用 | 手動譯文永遠可用，AI 失敗不阻斷 | REQ-07 |
| 跨日未練 | 不記失敗、不累積債 | M7 |
| 課件 contentHash 改變 | 只重置該 Lesson 進度 | M6 |
| 歸檔滿 168 小時 | EXPIRED 不可逆 | M8 |
| 發布工件缺 sidecar | build/zip 中止，不產可疑 release | M9 |

## 5. 業務規則與約束

| 規則編號 | 規則描述 | 來源 |
|----------|----------|------|
| BR-001 | 原聲不可替換；播放/匯出不可使用 TTS、合成、生成、跨來源拼接 | M1 |
| BR-002 | 疊加單位是音節，不吸附單字邊界 | M2 |
| BR-003 | 合併匯出靜音 = 前一步 totalDurationMs，以 sample 數計 | M3 |
| BR-004 | sidecar 崩潰不可拖垮 App | M4 |
| BR-005 | Domain 純 Dart，副作用透過 ports | M5 |
| BR-006 | 進度合併 newer-wins，contentHash 只重置該課 | M6 |
| BR-007 | 跨日零懲罰 | M7 |
| BR-008 | ARCHIVED 168 小時內可恢復，EXPIRED 不可逆 | M8 |
| BR-009 | 發布授權白名單：MIT/BSD/ISC/Apache-2.0/LGPL dynamic | M9 |
| BR-010 | API key、錄音、音訊路徑不得落入 DB/pack/log/commit | M10 |

## 6. 前後端職責邊界（業務視角）

### 6.1 後端承擔的業務能力

- 音節切分、邊界驗證、零交越吸附與 `needsReview` 標示。
- 疊加步驟計算、原始 PCM 切片渲染、合併靜音規則。
- 韻律分析、錄音比對、錄音清理保證。
- `.abopack`/`.aboprogress` encode/decode、SRS、歸檔、進度合併。
- AIService credential/allowlist/rate limit/prompt guard。
- sidecar crash 隔離、release license/staging/packaging gate。

### 6.2 前端承擔的業務呈現與互動

- 匯入、階段進度、checkpoint 重試、錯誤不清空輸入。
- 波形、音節 chips、邊界拖動、undo、needsReview 視覺標示。
- 播放/錄音/匯出操作入口與狀態呈現。
- 課件庫、進度設定、AI key 輸入後即清空畫面欄位。
- 未簽章 release 使用說明由 README 承接，不在 App 內假裝已簽章。

### 6.3 禁止推諉清單

- M1/M2/M3 不得只靠 UI 文案約束，必須有 Domain 測試與 CI。
- API key 不得只靠「不要印」的慣例，必須走 Keychain adapter。
- 授權合規不得只靠人工記憶，必須由 license/staging/zip gate 擋。
- 錄音刪除不得只靠 UI 流程，必須由 compare/finally 路徑保證。

## 7. 需求追溯矩陣

| 需求編號/項目 | 業務摘要 | 設計檔案位置 | 任務拆分位置 | 狀態 |
|----------------|----------|--------------|--------------|------|
| REQ-01 | 匯入與音節對齊 | backend-design 介面 1 | task 3.1-3.5 | 已完成 |
| REQ-02 | 波形顯示與切點校正 | frontend FP3 / backend 介面 2 | task 3.6-3.7 | 已完成 |
| REQ-03 | 句尾疊加練習 | backend 介面 3-6 | task 4.1-4.4 | 已完成 |
| REQ-04 | mp3 匯出與合併靜音 | backend 介面 5-6 | task 4.5-4.7 | 已完成 |
| REQ-05 | 韻律分析 | backend 介面 7 | task 5.1-5.2 | 已完成 |
| REQ-06 | 錄音比對 | backend 介面 8 | task 6.1-6.2 | 已完成 |
| REQ-07 | 課件與譯文 | backend 介面 9-12 | task 7.1-7.2 | 已完成 |
| REQ-08 | 進度/SRS/歸檔 | backend 介面 13-19 | task 7.3-7.6 | 已完成 |
| REQ-09 | 架構、CI、授權、發布 | guardrails/release design | task 2.1、8.*、9.1-9.2 | 已完成；使用者端 smoke 待跑 |

## 8. 開放問題（業務側）

| 編號 | 問題 | 待確認方 |
|------|------|----------|
| B-001 | 未簽章 zip 的使用者說明是否足夠好懂 | Karen |
| B-002 | 使用者端完整 GUI smoke 後是否要正式標 v1 可分發 | Karen |
| B-003 | 未來是否補 Apple Silicon/universal binary | Karen，macOS v1 驗收後再評估 |
