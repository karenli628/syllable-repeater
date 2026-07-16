id: PIT-20260714-finder-debug-app-workspace-cwd-black-screen
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation S8 黑畫面診斷（2026-07-14）
context: macOS Debug App 從 Finder 或 `open -a` 啟動時，Directory.current 通常不是 repository workspace；App 在 runApp 前讀取 SidecarPaths.dev()，若只從 current directory 找 workspace，會先拋 StateError，使用者只看到黑色視窗。
action: SidecarPaths.dev() 保留 SYLLABLE_REPEATER_DEV_ROOT 明示覆寫，並把 Directory.current 與 Platform.resolvedExecutable.parent 都列為 workspace 搜尋起點，向上找含 name: syllable_repeater_workspace 的 pubspec.yaml；以 Finder 等效 open -a 重建並啟動驗證。
result: 修正後 Debug App 可從 Finder-style open 啟動；process 存活、視窗 visible、content size 1100x700，runtime log 無 StateError；完整 CI 137/137 App、Domain 159/159、Infra 96/96 PASS。
reasoning: GUI 啟動的 current directory 不受使用者點擊位置保證；可執行檔位於 repository build 產物內，沿 executable path 搜尋能涵蓋 Finder 啟動，同時不把本機帳號或絕對路徑硬編碼進程式。
recommendation: macOS app 若啟動黑屏，先查 runApp 前的路徑／初始化例外與 macOS log；開發路徑解析不可只依賴 Directory.current，保留環境變數覆寫，並用 `open -a` 從非 workspace cwd 做一次回歸驗證。
confidence: high
status: active
verified_count: 1
created: 2026-07-14
last_used: 2026-07-14
