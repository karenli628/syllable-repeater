id: WF-20260707-qwenasr-benchmark-borrow-points
type: workflow
scope: project
source: syllable-repeater / fullstack-code-review 隨附對照分析（github.com/karenli628/QwenASRMiniTool，shallow clone 實讀原始碼）
context: 專案剩餘高風險段＝2.1（sidecar 實體工件）與 9.1/9.2（release 發布）。QwenASRMiniTool 是同作者已出貨多版的 Windows Python 工具，出貨經驗可轉移。完整分析在 review/report-3-qwenasr-benchmark.html。
action: 定案 6 個借鏡落點（依優先序）：①downloader.py 模式→scripts/fetch_sidecar_artifacts.py（SHA-256 pinning＋斷點續傳＋主備援源，來源必須 LGPL-shared FFmpeg）；②「工具就緒狀態」設定頁區塊（擴充既有 demucsReadyProvider/missingPaths）；③make_release_zip 腳本化（版本單一來源＋排除 dev 工件＋SHA256SUMS＋安裝說明）；④使用者 README 範式（價值主張＋隱私承諾＋阿嬤級三步安裝）；⑤模型檔預檢（大小/magic bytes/煙霧測試，防半截模型神祕失敗）；⑥孤兒 sidecar 啟動清掃 pidfile（macOS 父死不殺子；Windows 版翻譯 proc_guard Job Object）→backlog。
result: 三份 HTML 報告之一（report-3）交付；行動①〜③已寫進 docs/codex/prompts.md 的 P2/P4 提示詞。
reasoning: 借「出貨最後一哩」的模式而非程式碼——它的工程紀律（無測試、單檔 3300 行）反而是本專案不可倒退的對照組。
recommendation: 執行 2.1/9.x 時先讀 report-3。四個絕不可照抄的地雷：①BtbN gpl-essentials 下載源（違 M9）；②downloader 的 SSL CERT_NONE 降級（違安全基線，改用憑證必驗＋SHA pinning）；③單檔巨型 UI；④api_server/cf_tunnel/批次（Non-scope 5 與 v1 範圍外）。自我更新（updater.py 模式）留 Phase 2 取得 Developer ID 後再評。
confidence: high
status: active
verified_count: 1
created: 2026-07-07
last_used: 2026-07-07
