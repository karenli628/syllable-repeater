// AI-Generate
# business-overview

## 業務目標

Syllable Repeater 幫單一學習者把英文音檔切成音節，從句尾開始逐步疊加跟讀，並在本機完成校正、播放、匯出、錄音比對、課件保存與 SRS 複習。產品價值不是生成新聲音，而是保留原聲並讓使用者用更細的音節單位練習。

## 核心規則

| 規則 | 說明 |
|------|------|
| 原聲不可替換 | 播放/匯出音訊逐 sample 來自原始 PCM 切片，禁止 TTS/AI 合成/跨來源拼接 |
| 音節疊加 | 步數 = 音節總數；第 n 步 = 句尾倒數 n 個音節到句尾 |
| 金標準 | `She has excellent communication skills` = 11 音節、10 切點、11 步 |
| 靜音規則 | 合併匯出段落間靜音 = 前一步 totalDurationMs |
| 本機隱私 | API key 只進 Keychain，錄音比對後清理，DB/pack/log 不存敏感資料 |
| 授權白名單 | release bundle 不得含 GPL/AGPL/non-commercial/research-only；FFmpeg 必須 LGPL dynamic shared |

## 業務流程

1. 使用者匯入音檔與可選字稿。
2. 系統自動對齊詞與音節，估計切分標示 `needsReview`。
3. 使用者校正切點並開始句尾疊加練習。
4. 使用者匯出 mp3 或錄音比對，系統只保留非音訊結果。
5. 使用者保存 `.abopack` 與 `.aboprogress`，SRS 跨日零懲罰。
6. v1 以未簽章 macOS x86_64 zip 交付。

## 範圍外

手機端、Windows、雲端同步、伺服器、批次匯入、TTS/AI 合成音訊、金流、Apple 官方簽章/notarization、Apple Silicon/universal binary 均不屬於 macOS v1。
