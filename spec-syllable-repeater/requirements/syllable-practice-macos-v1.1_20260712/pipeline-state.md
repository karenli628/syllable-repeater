# pipeline-state(格式固定:只改值,不改鍵、不改行序、不加段落;更新=整檔照本模板重寫)
schema: 1
project: syllable-repeater
requirement: syllable-practice-macos-v1.1_20260712
stage_skill: project-archive
slice: v1.1-archive
stage_status: done
next_skill: ops-monitoring
open_tasks: none
blocked_reason: none
next_patrol_due: none
last_handoff: 交接檔-20260712-01-fullstack-design_v1.1設計定稿_接task-split_中斷USER.md
last_updated: 2026-07-16
updated_by: claude-code

<!-- 欄位規則(本註解隨檔保留,供人與 check_handoff.py 對照;行數上限不計本註解):
- 落點:spec-<專案代號>/requirements/<需求目錄>/pipeline-state.md(一個需求一份)。
- stage_skill / next_skill:只能是套件 16 個 skill 名之一,或 none。
- stage_status:in_progress|done|blocked 三選一。
- open_tasks:只抄 task-split 的「編號」,不抄任務內文——state 不是第二本帳。
- blocked_reason:無則 none;有則一句話並引用任務編號。
- next_patrol_due:只由 ops-monitoring 收尾更新;無 monitoring-plan 則 none。
- last_handoff:只由 handoff skill 更新(與 handoffs/LATEST.md 同步)。
- 單一寫者:進度欄位只由各階段 skill 的「收尾掛接」第 2 步更新。
- 正文(不含本註解)≤30 行;日期一律 YYYY-MM-DD。
- 檔案損壞或與產物矛盾時:以產物證據為準(pipeline-navigator 完整掃描),
  向使用者回報建議內容,同意後刪掉重建。
-->
