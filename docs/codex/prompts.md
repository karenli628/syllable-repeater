# Codex 提示詞庫（Syllable Repeater）

> 用法：Codex 開新對話（工作目錄＝repo 根，會自動讀 `AGENTS.md`）→ 依任務複製下方對應提示詞貼上。
> 結構沿用專案交接檔的「8 段啟動提示範本」（讀原則 → 讀記憶 → 讀交接檔 → 定位階段 → 完成量 → 動工點 → 拍板 → 雷區）。
> 若 Codex 沙盒讀不到 `~/Karen_Memory/Dev_Memory/`（或舊路徑 `02_Memory/`），可略過該行——AGENTS.md 已內嵌憲法與偏好的關鍵摘要。

---

## P0・通用 session 起手（任何任務前先貼這段的變體）

```text
你在 Syllable Repeater repo 工作。先讀 AGENTS.md 全文並遵守其中紅線與風格守則；
若可存取家目錄，再讀 ~/Karen_Memory/Dev_Memory/constitution.md 與 preferences.md
（相容期內舊路徑 ../02_Memory/ 亦可，2026-09-07 後移除）。
接著讀 spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
與根目錄最新一份「交接檔-*.md」。

目前階段 <skill 名稱> / <切片編號> / <工作項目>。
上一 session 已完成 <完成清單>，tests <統計> 全綠。
請按 task-split <任務編號> 動工。

拍板：<使用者已拍板事項；無則寫「無」>。
不要：<本任務相關雷區，見 AGENTS.md §5>。

工作規則：動工前 flutter pub get；交付前 bash scripts/ci_core_checks.sh 必須全綠；
新檔案第一行 // AI-Generate；測試描述寫 CT-xx/AT-xx 編號；
完成後產出交接檔（格式照根目錄既有交接檔的末章範本）。
```

---

## P1・修復本輪審查的 2 條 important（建議最先做）

```text
你在 Syllable Repeater repo 工作。先讀 AGENTS.md，
再讀 spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/review/code-review-report.md
的「修復清單」。

目前階段 fullstack-code-implementation / 審查修復 / I-001＋I-002。
請完成：

1) I-001（一行）：guardrails/hard-limits-matrix.md 第 87 行「20 條 PARTIAL」改為「19 條」，
   改完跑 python3 scripts/check_guardrails.py <matrix> <decision-log> 確認仍通過。

2) I-002（三同步，順序固定）：
   a. 先在 design/backend-design.md §3.2.8 錯誤碼總表新增兩列：
      ERR_TRANSCRIBE_FAILED（whisper 轉寫 exit≠0，文案「辨識失敗，可重試」）、
      ERR_SEPARATE_FAILED（demucs 未產出 vocals，文案「人聲分離失敗，可跳過分離重試」）；
      並在 design/frontend-design.md 功能點 8 對照表補同兩碼的前端策略。
   b. packages/domain/lib/src/errors.dart 增加兩個常數。
   c. packages/infra/lib/src/sidecar/whisper_transcriber.dart（exit≠0 與 JSON 未產出兩處）
      改拋 ERR_TRANSCRIBE_FAILED；demucs_separator.dart（exit≠0 與 vocals 未產出兩處）
      改拋 ERR_SEPARATE_FAILED。
   d. app/lib/shared/error/error_messages.dart 補兩碼的 ErrorPresentation；
      注意 app/test 內有「17 碼數量」斷言的 widget test，同步改為 19 並更新設計檔中
      「17 碼」字樣（backend-design §3.2.8 前言、frontend-design 功能點 8 前言、errors.dart 註解）。
   e. 對應單元測試：whisper/demucs wrapper 測試中斷言新錯誤碼。

拍板：新增兩碼的名稱與文案如上（審查報告 I-002 建議案）。
不要：動 ERR_DECODE_FAILED 既有語意（解碼場景保留）；不要在 domain 引入 dart:io；
不要改 analysis_pipeline 泛型 catch 之外的錯誤流。

交付前 bash scripts/ci_core_checks.sh 全綠；完成後更新 code-review-report.md 修復清單
的狀態欄（待修復→已修復），並產出交接檔。
```

---

## P2・任務 2.1：sidecar 實體工件與 release staging

```text
你在 Syllable Repeater repo 工作。先讀 AGENTS.md（特別是 §2 紅線 4 與 §5 地雷），
再讀 task/task-split.md 任務 2.1 的進度註記、scripts/prepare_release_sidecars.py、
scripts/test_prepare_release_sidecars.py 與 release/license-manifest.json。

目前階段 fullstack-code-implementation / 2.1 / x86_64 sidecar 實體整備。
staging gate、SidecarPaths.bundled()、Release build phase 均已落地；缺的是實體工件。

請完成：
1) 盤點工件現況：.local-tools/ 下 whisper-cli 與 ggml-small.en.bin 應已存在；
   缺 LGPL-shared FFmpeg/ffprobe 與 demucs.cpp.main＋ggml-model-htdemucs-4s-f16.bin。
2) 寫 scripts/fetch_sidecar_artifacts.py（模式參考報告三優先 1）：
   每個工件宣告「來源 URL＋SHA-256＋授權」三元組；下載支援續傳；
   憑證驗證失敗即失敗（禁止 CERT_NONE 降級）；
   demucs.cpp 若無官方二進位發布，改輸出「本機編譯指令清單」並檢查本機產物。
   FFmpeg 來源必須是 LGPL shared build（禁止 --enable-gpl / --enable-nonfree / static）。
   來源 URL 選定前先列出候選與授權證據，等使用者確認後再寫死。
3) 工件就緒後跑 python3 scripts/prepare_release_sidecars.py（先 --dry-run 再實跑），
   全綠後把 task-split 2.1 勾選、license-manifest 若有新元件同步補列。

拍板：demucs CLI 契約＝demucs.cpp.main <model> <wav> <outdir>、vocals=target_3_vocals.wav。
不要：把 /usr/local/bin/ffmpeg（GPL build）放進 staging；不要繞過或弱化 license gate；
不要動 Apple Silicon（Non-scope，x86_64 先行）。

交付前 bash scripts/ci_core_checks.sh 全綠＋python3 -m unittest scripts/test_prepare_release_sidecars.py。
```

---

## P3・任務 7.2：真 Keychain 與 AI provider HTTP adapter

```text
你在 Syllable Repeater repo 工作。先讀 AGENTS.md，再讀
packages/domain/lib/src/ai/ai_service.dart、ports/secure_store.dart、ports/ai_client.dart、
app/lib/features/progress/ai_settings_service.dart，以及 task-split 7.2 的進度註記。

目前階段 fullstack-code-implementation / S6 / 7.2 真 adapter 接線。
Domain 側（AIService：rate limit、host allowlist、https-only、prompt-injection sanitizer、
manual 覆蓋規則、audit）已完成且有測試；缺 infra 真實作。

請完成：
1) infra 新增 KeychainSecureStore（flutter_secure_storage，macOS Keychain）實作 SecureStore port；
   金鑰名沿用 AIService.credentialKey（ai.apiKey）。
2) infra 新增 HttpAiClient 實作 AiClient port：依 AiProviderConfig（baseUrl/model）呼叫
   OpenAI 或 Anthropic 相容 chat/messages API 做翻譯；逾時、非 2xx、格式錯誤一律丟例外
   讓 AIService 包成 ERR_AI_CALL_FAILED；不得在錯誤或 log 中輸出 key。
3) app 端把 InMemoryAiSecureStore / NoopAiClient 換成真實作（維持可測：測試仍注入 fake）。
4) 測試：HttpAiClient 用假 HTTP server 或注入的 client 測；斷言 key 不出現在任何 log/錯誤字串。
5) 完成後逐條複核 hard-limits-matrix #11/#19/#20/#22/#23/#31/#34 的 PARTIAL 註記，
   能升 IMPLEMENTED 的更新落地位置與證據（狀態統計表與交付備忘的數字要一起改，
   並全文搜尋舊數字防止再現 I-001）。

拍板：服務商先支援 api.openai.com 與 api.anthropic.com（allowlist 既有兩家）。
不要：AIService 之外開任何直連外部的旁路；不要把 key 寫進 DB/log/pack/測試 fixture；
不要讓 domain import http 或 flutter_secure_storage（都放 infra/app）。

交付前 bash scripts/ci_core_checks.sh 全綠。
```

---

## P4・任務 9.1＋9.2：release build 與免簽章發布

```text
你在 Syllable Repeater repo 工作。先讀 AGENTS.md §5（sandbox 地雷）與
task-split 9.1/9.2、release/release-checklist.md、
app/macos/Runner/Scripts/copy_release_sidecars.sh。前置：2.1 已完成（staging 就緒）。

目前階段 fullstack-code-implementation / 收尾 / 9.1 release build → 9.2 打包發布。

請完成：
1) 9.1：app/macos/Runner/DebugProfile.entitlements 與 Release.entitlements 的
   com.apple.security.app-sandbox 改 false（使用者 2026-07-05 已拍板）；
   flutter build macos --release；驗證 build phase 的 sidecar staging 檢查通過；
   確認 FFmpeg 為 LGPL 動態連結並隨附授權告知文件（AT-09-05）。
2) 9.2：寫 scripts/make_release_zip.py（模式參考報告三優先 3）：
   版本號單一來源、打包未簽章 .app、排除 dev 工件、產 SHA256SUMS、
   隨附一頁式「安裝說明.md」（下載→xattr -cr 或右鍵開啟→完成，附截圖位）。
   同步寫使用者導向 README（結構參考報告三優先 4：價值主張＋隱私承諾＋三步安裝）。
3) 實機驗收對照 AT-09-03：略過 Gatekeeper 後 REQ-01→08 全流程可跑（不能自動驗的
   項目列成人工驗收清單交使用者執行，不要自稱已驗）。

拍板：免簽章＋略過 Gatekeeper 路線（requirement v1.2）；不做 notarization、不上架。
不要：加 temporary-exception entitlements（免簽章下無效）；不要做自我更新（Phase 2）；
不要做 Apple Silicon/universal binary。

交付前 bash scripts/ci_core_checks.sh 全綠；release checklist 逐項打勾留證據。
```

---

## P5・需求變更時（先防線後實作）

```text
使用者提出需求變更：「<變更內容>」。
先不要寫程式。讀 AGENTS.md §2 紅線與
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md
的 §2.4 Non-scope 與 §2.5 核心維持原則，然後逐題回答七題變更防線檢查表：
1 會破壞核心流程嗎（對照 2.5 不可接受清單）
2 會造成資料不一致嗎
3 會讓權限變得不清楚嗎
4 會讓外部服務影響核心規則嗎
5 需要新增測試嗎
6 需要更新需求成稿嗎
7 需要調整架構嗎
把七題答案完整列出；任何一題為「是」，先說明處理方案並停下等使用者確認，
確認後才依三同步（文件→程式→測試）實作。
```

---

## P6・請 Codex 做 code review（複審用）

```text
你在 Syllable Repeater repo 工作。先讀 AGENTS.md 與
review/code-review-report.md（上一輪基準）。
對 <指定範圍：如「自 commit 8cf46dd 之後的 diff」> 做審查：
- 紅線核對：M1（renderStep 唯一路徑）、M2（不吸附）、M5（domain 純度）、M9/M10（授權/隱私）
- 風格核對：AGENTS.md §4 十二條逐條
- 錯誤碼：新增碼是否三同步（backend-design §3.2.8 / errors.dart / error_messages.dart / 測試）
- 上一輪 I-*/S-* 是否修復、是否引入新問題
輸出：發現按 blocking/important/suggestion/nit/praise 分級，每條附 檔案:行號＋修法＋規範出處；
最後給結論（透過/有條件透過/不透過，規則：blocking>0 或 important≥5 即不透過）。
只報告，不要直接改碼。
```
