id: WF-20260707-codex-agent-interface
type: workflow
scope: project
source: syllable-repeater / fullstack-code-review 隨附交付（使用者要求 Codex coding agent 提示詞/指令/文檔）
context: 使用者計畫讓 Codex 接手部分後續工作（2.1/7.2/9.1/9.2 與審查修復）。Codex 沒有本套件的記憶系統與 skills，需要把守則內嵌成它會自動讀的檔案。
action: 建立三件套：①repo 根 `AGENTS.md`（Codex 自動讀取）＝紅線 M1–M10 摘要＋架構邊界＋12 條風格守則＋已知地雷（sandbox/--no-gpu/Drift tableName/GPL ffmpeg 等）＋「不要動的東西」清單；②`docs/codex/prompts.md`＝P0 通用起手＋P1 審查修復＋P2 任務 2.1＋P3 任務 7.2＋P4 任務 9.1/9.2＋P5 變更防線七題＋P6 複審提示詞（沿用交接檔 8 段啟動範本結構）；③`docs/codex/commands.md`＝指令速查＋常見症狀對照表。
result: Codex 開新對話→自動讀 AGENTS.md→貼對應 P 系列提示詞即可動工；本機交付閘門與 CI 同源（bash scripts/ci_core_checks.sh）。
reasoning: 記憶與憲法無法跨工具攜帶，但可以把「違反即失敗」的規則降維成 agent 原生慣例（AGENTS.md）；提示詞沿用既有 8 段範本可保持跨工具交接一致性。
recommendation: ①任務內容變動時同步維護 prompts.md（尤其拍板事項與雷區段）；②AGENTS.md §6 現況段每完成一個任務就更新，避免 Codex 讀到過期進度；③若要 Codex 執行完整 skill 流程（而非只遵守守則），另跑 spec-skills-refresh 同步 skills/ 到 Codex 技能目錄；④Claude 端 session 也應遵守 AGENTS.md（單一守則來源，避免兩套規則漂移）。
confidence: high
status: active
verified_count: 1
created: 2026-07-07
last_used: 2026-07-07
