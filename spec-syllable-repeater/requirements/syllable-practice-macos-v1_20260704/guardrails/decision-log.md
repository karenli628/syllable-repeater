# decision-log.md — 硬性限制不適用理由紀錄

> 專案：Syllable Repeater macOS v1（`syllable-practice-macos-v1_20260704`）
> 建立日期：2026-07-05
> 規則：matrix 中每個 `NOT_APPLICABLE_PENDING_HUMAN_REVIEW` 都必須在此有一條紀錄，缺一即檢查失敗。
> **AI 不得自行把「人類裁決」欄填為批准**；裁決由人類寫入或口頭確認後由 AI 代填並註明「使用者於 <日期> 確認」。

---

## DL-001

- **對應限制**：`4 API Schema`
- **AI 判斷**：不適用
- **不適用理由**：本專案無 HTTP／gRPC／WebSocket 對外介面（backend-design §2「無 HTTP 介面」）。前端型別直接複用 domain 套件的 Dart class/record，介面對齊錨在「Domain 公開 API（backend-design.md §3.2 介面 1–19）＋17 錯誤碼總表」，而非 REST/GraphQL schema。
- **目前假設條件**：僅本機 App，無伺服器；AIService 呼叫外部翻譯 API 屬 SDK 級（服務商定義 schema）非本專案自定 API。
- **未來何時會變成適用**：若引入手機端（REQ-09 Phase 2）走商店 App 且需與桌面同步／若開放 HTTP 分享課件／若引入多裝置同步。
- **不做的風險**：若假設被打破而新增 HTTP 介面，缺 API schema 驗證會導致格式錯亂與注入攻擊。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-002

- **對應限制**：`9 Branch Protection`
- **AI 判斷**：不適用
- **不適用理由**：專案為單人開發，且尚未 `git init`；無合併請求流程、無需擋 PR。
- **目前假設條件**：單一維護者、無 code review 流程、無多 branch 併行。
- **未來何時會變成適用**：若使用者建立 GitHub repo 並找他人 review／或未來 Phase 2 團隊成長。
- **不做的風險**：解 block 後若不加分支保護，未經檢查的 code 可能被直接推到 main。
- **是否需要人類確認**：是
- **人類裁決**：`REJECTED_NEEDS_IMPLEMENTATION`　（使用者 eslite0220@gmail.com 於 2026-07-05 拒絕 AI 判斷、要求實作；見 task-split.md task 8.4.x）

---

## DL-003

- **對應限制**：`10 CODEOWNERS`
- **AI 判斷**：不適用
- **不適用理由**：單人 repo，唯一 owner 就是使用者本人；無需指定他人 review 特定檔案。
- **目前假設條件**：使用者本人是唯一維護者。
- **未來何時會變成適用**：招募協作者、關鍵路徑檔案要求特定角色 review。
- **不做的風險**：若後續加入他人協作但沒設 CODEOWNERS，敏感檔案（sidecar wrapper、schema、entitlements）可能被誤改。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-004

- **對應限制**：`15 RBAC`
- **AI 判斷**：不適用
- **不適用理由**：App 只有一個使用者角色（本機使用者）；無管理員／訪客／付費會員等角色區分。
- **目前假設條件**：本機自用工具、無多使用者。
- **未來何時會變成適用**：若改為家庭共享版（家人＝子帳號）／若 SaaS 化。
- **不做的風險**：若假設被打破，所有人擁有同一份權限＝失去角色控制。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-005

- **對應限制**：`16 ABAC`
- **AI 判斷**：不適用
- **不適用理由**：無角色（見 DL-004）也無屬性維度（部門／時段／標籤）可作為授權判斷。
- **目前假設條件**：同 DL-004。
- **未來何時會變成適用**：若引入「工作時段免打擾」「兒童模式」等基於使用時段／使用者屬性的功能。
- **不做的風險**：低（單人）。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-006

- **對應限制**：`17 Tenant Isolation`
- **AI 判斷**：不適用
- **不適用理由**：本機 App 無租戶概念——只有一台機器一份資料；SQLite DB 屬於當前 macOS 使用者。
- **目前假設條件**：本機一份 DB／一份設定；無雲端多租戶架構。
- **未來何時會變成適用**：若改為 SaaS 版／若多使用者共享同一份 backend。
- **不做的風險**：若假設被打破而未加租戶隔離，客戶資料互相可見＝嚴重外洩。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-007

- **對應限制**：`18 RLS`
- **AI 判斷**：不適用
- **不適用理由**：無多使用者（見 DL-006）；SQLite 也不原生支援 RLS。
- **目前假設條件**：同 DL-006。
- **未來何時會變成適用**：若改為多使用者 SaaS 並選用 PostgreSQL/Supabase。
- **不做的風險**：同 DL-006。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-008

- **對應限制**：`21 KMS`
- **AI 判斷**：不適用
- **不適用理由**：AI key 走 macOS Keychain，這已是 OS 級的金鑰管理服務（含系統輪替 policy）。本機自用工具無需另建 AWS KMS／HashiCorp Vault／GCP KMS 等雲端 KMS。
- **目前假設條件**：僅使用者自己的 AI key 需要保護；使用者本人管理 key 生命週期。
- **未來何時會變成適用**：若 App 要保管他人 key／若走 SaaS 需管理服務端金鑰。
- **不做的風險**：低——Keychain 已提供加密保管、未來替換 key 由使用者手動更新即可。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-009

- **對應限制**：`22 Audit Log`
- **AI 判斷**：不適用
- **不適用理由**：單人本機工具，無「誰在何時做了什麼」的稽核需求；attempt 表記錄的是練習結果（產品資料）而非操作稽核；SRS 狀態變更由使用者自己在 App 內看得到。
- **目前假設條件**：使用者本人是唯一操作者且不需要事後查誰改了什麼。
- **未來何時會變成適用**：若他人可能碰到這台電腦／若團隊或商用情境。
- **不做的風險**：無法追查「資料為何變成這樣」，但單人情境下這通常等於「你自己想不起來為什麼」，屬可接受風險。
- **是否需要人類確認**：是
- **人類裁決**：`REJECTED_NEEDS_IMPLEMENTATION`　（使用者 eslite0220@gmail.com 於 2026-07-05 拒絕 AI 判斷、要求實作；見 task-split.md task 8.4.x）

---

## DL-010

- **對應限制**：`23 Rate Limit`
- **AI 判斷**：不適用
- **不適用理由**：本 App 不對外提供服務；使用者呼叫外部翻譯 API 的 rate limit 由服務商端控制，客戶端另加無實質保護。
- **目前假設條件**：使用者不會用 App 惡意壓自己的 AI 服務商配額。
- **未來何時會變成適用**：若 App 開放公用端點／若引入伺服器代理 AI 呼叫。
- **不做的風險**：使用者本人狂點翻譯耗光配額——由服務商端 rate limit + 使用者自己付費察覺。
- **是否需要人類確認**：是
- **人類裁決**：`REJECTED_NEEDS_IMPLEMENTATION`　（使用者 eslite0220@gmail.com 於 2026-07-05 拒絕 AI 判斷、要求實作；見 task-split.md task 8.4.x）

---

## DL-011

- **對應限制**：`24 Quota`
- **AI 判斷**：不適用
- **不適用理由**：本 App 無多使用者、無金流；儲存空間由使用者自己的磁碟決定；AI API 費用由使用者直付服務商。
- **目前假設條件**：使用者自付所有資源成本。
- **未來何時會變成適用**：若走 SaaS 訂閱制／若提供「免費額度」。
- **不做的風險**：低（單人自付）。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-012

- **對應限制**：`28 Immutable Log`
- **AI 判斷**：不適用
- **不適用理由**：無稽核情境（見 DL-009）；attempt 表允許修改亦符合 M7「跨日零懲罰」（允許使用者靜默作廢的舊嘗試）。
- **目前假設條件**：無需保留不可竄改的操作歷史。
- **未來何時會變成適用**：若走商用審計、法規遵循情境（金融、醫療、法遵）。
- **不做的風險**：無法證明歷史紀錄未被竄改，但單人自用不需要。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-013

- **對應限制**：`31 Network Policy`
- **AI 判斷**：不適用
- **不適用理由**：無雲端基礎設施；App 出站連線只有一個路徑 = AIService 對翻譯服務商 HTTPS API（且僅在使用者設 AI key 時觸發，屬 opt-in）。無 VPC、無 security group、無 mesh 需要 network policy 管控。
- **目前假設條件**：App 只是一個桌面 process，無伺服器端。
- **未來何時會變成適用**：若走雲端多服務架構／若引入自建代理。
- **不做的風險**：低（單一出站端點，靠 macOS network extension／firewall 已足夠使用者側控制）。
- **是否需要人類確認**：是
- **人類裁決**：`REJECTED_NEEDS_IMPLEMENTATION`　（使用者 eslite0220@gmail.com 於 2026-07-05 拒絕 AI 判斷、要求實作；見 task-split.md task 8.4.x）

---

## DL-014

- **對應限制**：`33 Content Filter`
- **AI 判斷**：不適用
- **不適用理由**：無 UGC（使用者上傳內容供他人瀏覽）情境；使用者字稿是自己輸入的自用資料，無需擋色情／暴力／仇恨言論等內容過濾；音檔為使用者提供的練習素材，屬個人使用。
- **目前假設條件**：使用者自產自用內容；App 內容不對第三方展示。
- **未來何時會變成適用**：若引入「分享課件庫」「社群」／若走教育機構部署（需擋不當內容）。
- **不做的風險**：無多方觀看者的情境下無需 content filter。
- **是否需要人類確認**：是
- **人類裁決**：`APPROVED_NOT_APPLICABLE`　（使用者 eslite0220@gmail.com 於 2026-07-05 確認）

---

## DL-015

- **對應限制**：`34 Prompt Injection Guard`
- **AI 判斷**：不適用
- **不適用理由**：AIService.translate 送給服務商的字稿**只**來自使用者自己在 App 內輸入的文字；無 web scrape、無他人上傳、無檔案匯入外部 markdown／email／HTML 進 prompt。使用者不會對自己植入 injection payload；即使意外貼上惡意文字，也是使用者對自己的服務商帳單負責。
- **目前假設條件**：所有進入 AI prompt 的文字皆為使用者本人輸入。
- **未來何時會變成適用**：若引入「網頁擷取歌詞」「PDF 匯入台詞」「其他人分享 pack」等外部不可信文字來源。
- **不做的風險**：低（無不可信輸入來源）；若假設被打破需重評並加 injection guard。
- **是否需要人類確認**：是
- **人類裁決**：`REJECTED_NEEDS_IMPLEMENTATION`　（使用者 eslite0220@gmail.com 於 2026-07-05 拒絕 AI 判斷、要求實作；見 task-split.md task 8.4.x）

<!-- 依序遞增 DL-016…；已裁決的紀錄保留不刪，作為稽核軌跡。 -->
