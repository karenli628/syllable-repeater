id: WF-20260706-sidecar-optional-dependency-injection
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S1c task 3.8 + FP2 UI 提示
context: 需求 §2.5 M4「任一 sidecar 崩潰→回傳失敗＋App 不崩」延伸到「sidecar 缺失＝崩潰同等處理」——demucs 是 optional（Intel Mac 上跑得慢＋非人聲混音檔本來就不需要分離），不能因為 demucs 未裝就把整個 App 打回 preview runner。同時使用者若勾了 separateVocals 但沒裝 demucs，UI 端應該有意識到「將降級」的提示，而非靜默降級讓使用者困惑。
action: 三段式 pattern——①`SidecarPaths.missingPaths()` 只納**必需** sidecar（ffmpeg／ffprobe／whisper-cli／whisper-model／cmudict），demucs 走獨立 `demucsAvailable()` bool；②`InfraAnalysisRunner.fromPaths()` 依 `paths.demucsAvailable()` 條件性建 `DemucsCppVocalSeparator` 傳給 `AnalysisPipeline` 建構子；未就緒時 `vocalSeparator: null`，pipeline 內既有 `if (vocalSeparator != null)` 邏輯自動降級（M4 語意直接落地）；③`main.dart` 無條件 `overrideWithValue(demucsReadyProvider, paths.demucsAvailable())`（**不論真 pipeline 就緒與否**都要覆寫，讓 UI 拿到真值）；④UI `Consumer(demucsReadyProvider)` 於 `separateVocals` 勾選態＋未就緒時顯示 `Icons.info_outline` + Tooltip「將降級使用原音」，不阻斷使用者操作。
result: `InfraAnalysisRunner` code 面完成 demucs 條件注入；假 runner 錯誤映射 7/7 全綠；integration test skip if missing 樣板生效（使用者本機裝好後自動變綠）；UI 3 情境（ready 勾了不顯示／未 ready 未勾不顯示／未 ready 勾了顯示 tooltip）全綠；backend-design 第 704 行「demucs 失敗→跳過分離用原音」語意在 code 面已對應到「demucs 缺失＝跳過」＋UI 面有提示。
reasoning: 若把 demucs 也塞進 `missingPaths()`，會出現「你只想練純人聲檔卻因為沒裝 demucs 而整個 App 被降級到 preview」的荒謬情境——這違反 preferences「不強加不必要的環境需求」與「幫使用者降低低價值決策次數」。獨立的 `demucsAvailable()` 讓「必需檢查」與「選用告知」分層清楚。UI 端不能完全靜默降級（那樣使用者以為 demucs 有跑但實際沒），也不能強制擋住（那樣就是「demucs 必需」了）——tooltip 提示是最平衡的：使用者仍可勾（心裡有數會降級）或取消勾（不想要降級就改用原音檔）。
recommendation: 未來新增其他 optional sidecar（例：v1.5 WORLD pitch）或選用能力（例：GPU 加速的 whisper），一律套用同 pattern——①`XxxAvailable()` bool 於 `SidecarPaths`；②`InfraAnalysisRunner` 條件性建 adapter；③`main.dart` 無條件覆寫 provider；④UI 端 tooltip 顯示未就緒。**不要**把 optional 檢查藏在 adapter 內部 return null——那樣 UI 拿不到「未就緒」訊號、無法提示使用者。發布時（M9）可考慮把「未就緒＋使用者勾了」升級為 `Analytics` 事件記錄，方便統計使用者實際需要哪些 optional sidecar。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
