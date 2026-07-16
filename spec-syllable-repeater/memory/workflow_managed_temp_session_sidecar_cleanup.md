id: WF-20260715-managed-temp-session-sidecar-cleanup
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S9-22（2026-07-15）
context: Whisper、Demucs、練習預覽與課程解包若共用系統 temp 且只靠下次啟動全刪，會長期累積數百 MB；直接清空共用目錄又可能誤刪另一個仍執行 App instance 或使用者保存檔。
action: 每次 App 啟動建立 session-* 目錄並持有 .lease 非阻塞排他鎖；新 session 只刪可取得鎖的舊 session。Sidecar 作業用 finally 清中介檔，provider／切課清預覽與解包；刪除 API 以 path containment 限制只能處理本 session，另以使用者 pack 負向測試守住界線。
result: ManagedTempSession 20 作業／多 session 測試、Whisper／Demucs 成功失敗測試、課程解包後續故障注入與真 Sidecar 整合測試均通過；guardrails #62 轉 IMPLEMENTED。舊版遺留 298M 未自動刪除，需所有 App 關閉後由使用者批准一次性清理。
reasoning: session lease 同時解決重啟清理與多實例安全；作業完成即刪能控制峰值，session dispose／下次啟動則作最後兜底。使用者目的地永遠不進受管根目錄，避免以副檔名猜測所有權。
recommendation: 新增任何 sidecar、預覽或解包功能時，先指定 session operation 目錄、成功／失敗／取消 cleanup 契約與使用者目的地負向測試；不可回退到 Directory.systemTemp 共用固定資料夾或啟動時全刪。
confidence: high
status: active
verified_count: 1
created: 2026-07-15
last_used: 2026-07-15
