id: DEC-20260706-demucs-cpp-selected-mit-licence
type: decision
scope: project
source: syllable-repeater / fullstack-code-implementation S1c task 3.8（OQ-2 解決）
context: backend-design 第 750 行明訂 S1c 動工前必核 sevagh/demucs.cpp 的 LICENSE 檔內容——選型研究時只查得「原 Python Demucs 為 MIT」，但 C++ 移植版授權需回原始 repo 逐字核對。此為 M9「授權白名單」與 hard-limits-matrix #12 Dependency Scanning 的直接前置。
action: 透過 WebFetch 直接讀 `https://raw.githubusercontent.com/sevagh/demucs.cpp/main/LICENSE`：**MIT License, Copyright (c) 2023 Sevag H**，無 non-commercial、無 share-alike／copyleft 條款。主要依賴 Eigen 為 MPL-2.0（檔案級 copyleft，對主程式不傳染）。兩者皆通過需求 §2.5 M9「零 GPL/AGPL/非商用限定」白名單。OQ-2 拍板：demucs.cpp 移植版正式選定 sevagh/demucs.cpp。task-split 3.8 已勾選；hard-limits-matrix #12 進度補入本次核對結果。
result: 本輪落地 `DemucsCppVocalSeparator` adapter + 7 情境假 runner 測試 + integration test（skip if missing）；`InfraAnalysisRunner` 條件性注入；UI 端「未就緒」提示 3 情境測試全綠。demucs.cpp 二進位 build 與 htdemucs 模型下載屬使用者本機環境事宜，adapter code 已就位等實測。
reasoning: M9 屬「必須維持」核心原則，未核對 LICENSE 就寫 adapter 屬於 conatus（保住核心）違規——即使 code 最後過測試，也可能引入不合規的相依而在 M9 授權掃描（CT-09）時被擋。用 WebFetch 拿 raw LICENSE 檔比在 GitHub UI 猜「這 repo 好像顯示 MIT badge」更可靠——badge 可能為選填字段或分支不一致。Eigen MPL-2.0 通常被誤認為 copyleft；實務上 MPL-2.0 是「檔案級 copyleft」（修改後的 Eigen 檔案要開源，但**動態連結 Eigen 進主程式不影響主程式授權**），符合白名單。
recommendation: 未來新增 C++ sidecar 或 Dart package 時一律走同一 pattern：①WebFetch 抓 raw LICENSE 檔；②檢查是否含 non-commercial／share-alike／viral copyleft；③檢查主要依賴的 LICENSE（傳染型 copyleft 會拖累主程式）；④結果寫進 project memory + 更新 hard-limits-matrix #12。**不要**只憑 GitHub UI 或 npm 頁面上的 LICENSE 標籤——那些可能過時或錯誤。若使用者未來要加 Dependency Scanning 自動化（task 8.2 CT-09），本核對過程可直接對應成 CI 腳本樣板：`raw LICENSE fetch → regex match GPL/AGPL/proprietary → fail if hit`。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
