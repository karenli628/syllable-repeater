// AI-Generate
# S10 r6／r7 最終交付測試報告（2026-07-16）

## 完成範圍

- M1 原音／分析軌隔離、段落三態與 `.abolabel v2`、兩頁紅色播放軸與段落播放狀態機。
- 積木 1／1、整列 3／1、自然接合、切點殘影修正與 0/N 列練習連動。
- 錄音單次參考、背景 isolate、每圖最多 1000 點、目前單元記憶體回放與立即刪除。
- `.abopack v3` 複合封包、完整原始 PCM、單句來源範圍與四層匯出 provenance／相容性防線。
- 導覽名稱、Guardrails、授權、Intel 效能、Release 產物與真人驗收閉環。

## TDD 與拆批測試

- Domain：188/188 PASS。
- Infra：第一批 59 PASS、第二批 35 PASS＋1 項因未設定 `FFMPEG_PATH` 條件式 SKIP；該真 FFmpeg 匯出測試改以 Release 內建 FFmpeg 明確重跑 8/8 PASS。
- App：五批共 190/190 PASS（72＋39＋52＋26＋1）。`macos_window_config_test.dart` 首次從 repo 根目錄執行因 fixture 相對路徑失敗；改於正確的 `app/` 工作目錄重跑 1/1 PASS，屬執行目錄問題，不隱匿此紀錄。
- `flutter analyze`：No issues。
- 錄音限點紅測試先取得錯誤首點，最小修正為保留首尾並收集內部分桶 min/max 後轉綠；自訂積木／整列單次錄音參考測試為 650ms 且不含重複或靜音。
- 四層匯出 planner 與 v3 來源範圍先由紅測試鎖定 fingerprint／lessonId／range 相容性，再完成實作。

## 防線、授權與效能

- v1 guardrails：PASS（既有 37 項基線）。
- v1.1 guardrails：PASS（25 IMPLEMENTED、0 PARTIAL、0 BLOCKED）。
- 授權 manifest：25 components PASS；授權／Release sidecar Python 測試 23/23 PASS。測試輸出的 GPL 負例拒絕訊息是預期 fixture，整組 unittest 為 PASS。
- Intel i5-8259U、10 秒音訊 benchmark：4.132 秒；舊基準 4.689 秒、回歸上限 4.924 秒、需求上限 60 秒，PASS。
- 受環境單次 30 秒上限影響，未宣稱整支 `scripts/ci_core_checks.sh` 單次執行通過；以上為同源閘門拆批後的實際結果。

## Release 產物

- `flutter build macos --release` 成功；App bundle `du` 為 606MB，其中 sidecar／離線模型為 581MB，匯入音檔不會寫入 `.app` 而使本體持續膨脹。
- 內建 FFmpeg 8.1.2：shared build，明確為 `--disable-gpl --disable-nonfree`；真匯出 8/8 PASS。
- 使用 `Release.entitlements` ad-hoc 深層重簽後，`codesign --verify --deep --strict` PASS；`app-sandbox=false`、麥克風權限為 true；主程式為 x86_64。

## 人工驗收

使用者已明示「真人驗收OK」，涵蓋最新 Release 的 Finder 目視、觸控板／滑鼠手勢、段落播放、波形與真人麥克風。已取消的兩張社群圖不屬待辦或交付缺口。
