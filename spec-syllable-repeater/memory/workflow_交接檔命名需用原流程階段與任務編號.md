id: WF-20260705-handoff-naming-source-stage-task
type: workflow
scope: project
source: syllable-repeater / handoff naming correction
context: 2026-07-05 交接檔曾使用本 session 為對話方便臨時創造的 A/B/C/D 路線代號，造成檔名與內文偏離 `task-split.md`、execution-log 與 ai-dev-skills 原流程階段名稱。
action: 將交接檔檔名與內文回歸原流程來源：`fullstack-code-implementation`、`S1a`、`Frontend FP0/FP2`、`8.1 Domain 純 Dart CI-ready 防線`、`hard-guardrails matrix` 等；不得使用 session 臨時路線代號。新增或改交接檔時，檔名格式採 `交接檔-[yyyymmdd]-[目前階段-該階段工作項目編號或名稱].md`，其中 `[目前階段-該階段工作項目編號或名稱]` 必須取自 skill 階段、`task-split.md` 工作項目、或 execution-log 真實階段。
result: 後續交接檔可直接追溯到原流程與任務拆分，不會把對話中的臨時選項誤寫成正式專案狀態。
reasoning: 交接檔是跨 session 的事實來源；臨時代號只適合當下對話，寫入檔名或內文會讓新 agent 誤以為它是正式任務編號，破壞 C13 不臆測與 task-split 的追溯性。
recommendation: 新增交接檔前先核對 `task-split.md` 與 `execution-log.md`，檔名與標題只使用原流程階段與任務名稱，例如 `交接檔-20260705-fullstack-code-implementation_S1a-FP0_FP2剩餘.md`；若對話中出現 A/B/C/D 或其他臨時選項，交接時必須改寫回正式項目名稱。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
