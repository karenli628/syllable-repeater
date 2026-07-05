id: DEC-20260705-hard-guardrails-matrix-verdict
type: decision
scope: project
source: syllable-repeater / hard-guardrails skill 首輪
context: 依 hard-guardrails skill + `local-single-user` profile 建立 hard-limits-matrix（37 項）與 decision-log（15 條 NOT_APPLICABLE_PENDING）；使用者於 2026-07-05 逐條裁決。裁決依據＝本專案為本機自用桌面工具、免簽章（Q4）、無多使用者/無 SaaS/無稽核情境。
action: 15 條裁決結果——**APPROVED_NOT_APPLICABLE 10 條**：#4 API Schema（DL-001，無 HTTP）、#10 CODEOWNERS（DL-003，單人）、#15 RBAC/16 ABAC/17 Tenant Isolation/18 RLS（DL-004~7，無多使用者）、#21 KMS（DL-008，Keychain 已替代）、#24 Quota（DL-011，單人自付）、#28 Immutable Log（DL-012，無稽核）、#33 Content Filter（DL-014，無 UGC）。**REJECTED_NEEDS_IMPLEMENTATION 5 條**：#9 Branch Protection（單人 repo 也要防 force push）、#22 Audit Log（記錄自我設定變更）、#23 Rate Limit（防 AIService 手滑狂點）、#31 Network Policy（AI 服務商 domain allowlist）、#34 Prompt Injection Guard（未來拿線上歌詞當字稿情境）。5 條 REJECTED 對應 task-split.md 新增 8.4.1–8.4.5 實作追蹤。
result: matrix 統計 IMPLEMENTED 5／PARTIAL 17／APPROVED_NOT_APPLICABLE 10／REJECTED_NEEDS_IMPLEMENTATION 5／NOT_REVIEWED 0；`scripts/check_guardrails.py` 除 REJECTED 未實作外全綠；pre-push hook 會擋推遠端直到 5 條實作完成。
reasoning: 使用者從「粗略歸類」（僅多使用者/多租戶/稽核情境不適用）逐步細分——經 C13「揭露臆測」提問後，區分「本專案結構下無東西可實作（🔴 DL-001/003/008/014）」「有實作價值（🟢 DL-009/010/013/015）」「單人也能裝的價值有限項（🟡 DL-002）」，最終 REJECTED 集中在有實質防線落點的 5 條。DL-002 Branch Protection 特別——即使單人 repo 也可防 force push 意外，落地成本低。
recommendation: 未來變化重評觸發條件：①改為多使用者（家人共用）→ DL-004/005/006/007 需重評；②走 SaaS/多裝置同步 → DL-006/007/010/011/013 需重評；③拿外部歌詞/subtitle 當字稿 → DL-015 已 REJECT 需盡快實作；④取得 Apple Developer 帳號 → 可重評 sandbox 相關項（見 [[decision_macos_sandbox_ui_demo_waived_v1]]）。matrix 每次調整都要跑 `python3 scripts/check_guardrails.py <matrix> <decision-log>`；批准人欄一律填「eslite0220@gmail.com（使用者 <yyyy-mm-dd> 確認/REJECT）」。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
