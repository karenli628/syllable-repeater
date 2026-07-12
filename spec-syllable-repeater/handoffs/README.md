# Handoffs — 交接檔目錄

本目錄存放本專案跨 session 的交接檔（handoffs），依 `ai-dev-skills/skills/handoff/` 規範管理。

## 目錄結構

- `./` — 正式交接檔，**進版控**
- `./drafts/` — 未定版草稿（`.gitignore` 排除）
- `./archive/` — 舊史料歸檔

## 檔名規則

```
交接檔-<yyyymmdd>-<NN>-<skill-name>_<切片編號>_<工作項目關鍵字>.md
```

`NN`＝同日流水號，01 起。詳見 `ai-dev-skills/skills/handoff/references/handoff-naming-convention.md`。

## 路徑沿革

- **2026-07-07 之前**的交接檔（本目錄內日期 20260705～20260707 前兩份）：檔名未含流水號（-01/-02/-03），沿用當時規則。**內容中提及的 `02_Memory/` 路徑等同今日 `~/Karen_Memory/Dev_Memory/`**（2026-07-07 遷移），為保留歷史時點的真實狀態，不追改。
- **2026-07-07 起**：新增交接檔均遵守流水號規則與 9 段範本（含第 9 段「給人類貼給下一個 agent 的可複製提示詞」）。首份 dogfooding 為 `交接檔-20260707-03-fullstack-code-review_修繕+skills編修+改名.md`。
- **2026-07-12 遷移期豁免落地**：`scripts/check_handoff.py` 新增 `LEGACY_HANDOFF_CUTOFF = "20260712"` 常數與 `is_legacy_handoff()` 判定——**檔名日期 < 2026-07-12** 的交接檔即使首次 `git add`（原被判定為「新增」）亦豁免流水號與「> 型別:」聲明強制，比照 rename 遷移檔處理。2026-07-12 使用者裁定六份舊史料檔均屬**完成型**（S3/S4/S5/S6-LessonPackEngine/20260707-03/20260707-04），內文不追改型別聲明以避免竄改歷史。此日以後（含當日）的新交接檔仍全額檢查。

## 其他相關舊史料

- `archive/20260612-01-手機端討論.md` — 原名 `HANDOFF_手機端討論.md`（2026-06-12，早於本專案採用交接規範），2026-07-07 依新規則命名並歸檔。
- 專案早期計畫 `PLAN3.0.md` — 已移至 repo `docs/legacy/PLAN3.0.md`（非交接檔性質）。
