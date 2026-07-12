// AI-Generate
# 交接檔 20260707-04 · fullstack-code-implementation / S6-22 真 App smoke 修繕完成

> 本交接檔為使用者指定沿用的 04 檔完成版；S6-22 已完成，下一步接 `fullstack-code-review` 增量複審。
>
> 使用者指定：不要新增 05、不要改名，直接修改本檔作為下一次交接檔使用；因此沿用遷移期舊檔名格式，由 `LATEST.md` 聲明 `done`。

## 1. 讀原則檔

新 session 先依序完整讀取：

1. `AGENTS.md`
2. `~/Karen_Memory/Dev_Memory/constitution.md`
3. `~/Karen_Memory/Dev_Memory/preferences.md`
4. `~/Karen_Memory/Dev_Memory/MEMORY.md`

若新路徑不存在，回退 `<工作區>/02_Memory/`（相容至 2026-09-07）。禁止讀其他專案的 `spec-*/memory/`。

## 2. 讀本專案記憶（Precision > Recall）

本輪優先讀：

- `pitfall_record_plugin_lazy_init_indexedstack.md`
- `workflow_progress_import_export_domain_snapshot_m6.md`
- `workflow_export_ct03_domain_infra_fp5.md`
- `workflow_widget_test_real_async_needs_runAsync.md`
- `workflow_fp6_pack_service_practicegroup_linkage_s6.md`

## 3. 讀本交接檔

完整路徑：

```text
/Users/karen_files/vibercoding project/syllable repeater/spec-syllable-repeater/handoffs/交接檔-20260707-04-fullstack-code-implementation_2.1_SidecarArtifactFetchGate.md
```

## 4. 目前階段

目前為 `fullstack-code-implementation / S6-22 / GUI-smoke-remediation`，狀態 `done`。

已完成：

- `S6-22.1`：課件庫成為啟動首頁；左側開啟課件、右側文字資訊窗格。
- `S6-22.2`：設定頁集中 manual translation、儲存 `.abopack`、匯入/匯出 `.aboprogress`。
- `S6-22.3`：匯出全部選取／全部取消；寫入後檢查 MP3 實檔存在。
- `S6-22.4`：macOS WAV stop 收尾等待；記憶體錄音試聽；來源與播放暫存刪除。
- `S6-22.5`：新 `.aboprogress` 改為 ZIP＋`progress.json`，保留舊純 JSON 讀取相容。
- `S6-22.6`：完整 CI、x86_64 release rebuild、unsigned zip 與 SHA-256 重建。

## 5. 本 session 完成量

### 規格與設計

- `requirement.md` 升 v1.4：新增首頁／設定檔案管理、AT-04-07、AT-06-06、錄音隱私生命週期。
- `frontend-design.md` 同步首頁左右配置、設定檔案管理、錄音試聽、匯出實檔 gate。
- `task-split.md` 新增 S6-22.1～S6-22.6。
- `execution-log.md` 新增 S6-22 實作、完整 CI 與 release zip 證據。

### 程式

- `app/lib/shared/navigation.dart`
- `app/lib/features/library/library_screen.dart`
- `app/lib/features/progress/progress_settings_screen.dart`
- `app/lib/features/export/export_dialog.dart`
- `packages/infra/lib/src/practice/practice_exporter.dart`
- `app/lib/features/practice/practice_recording.dart`
- `app/lib/features/practice/practice_controller.dart`
- `app/lib/features/practice/practice_player.dart`
- `app/lib/features/practice/widgets/record_panel.dart`
- `packages/domain/lib/src/progress/progress_engine.dart`

### 已通過驗證

- `flutter analyze`：No issues。
- `progress_import_export_test.dart`：5/5。
- `practice_exporter_test.dart`：6/6（指定 release bundle 內 LGPL FFmpeg）。
- App target tests：41/41。
- 錄音增量回歸：17/17。
- release LGPL FFmpeg 命令實寫 MP3：16,971 bytes。
- `flutter run -d macos` 真 App 首頁成功，CGWindow 1100×728；截圖：
  `/private/tmp/syllable-repeater-flutter-run-home-20260712.png`。
- `bash scripts/ci_core_checks.sh`：通過（hard guardrails、handoff/pipeline-state、CT-09、domain 82/82、infra 74/74、app 75/75、`flutter analyze`）。
- `fetch_sidecar_artifacts.py --inventory-only`、`--run-prepare-dry-run`、`--run-prepare`：通過。
- `flutter build macos --release --no-pub`：通過，產出 x86_64 `.app` 634MB。
- release bundle FFmpeg：8.1.2、`--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`，`otool -L` 為 `@rpath` shared dylib + dynamic `libmp3lame.0.dylib`。
- release bundle demucs.cpp.main：只連系統 `Accelerate.framework`、`libc++`、`libSystem`。
- `python3 scripts/make_release_zip.py --dry-run` 與實跑：通過。
- 新 zip：`dist/SyllableRepeater-macos-x86_64-unsigned.zip`，524MB，SHA-256 `949c76cfdaf8b0e72702dabecca777110806aa01c7a27c17cc238f9dc12a383c`。
- `unzip -l` 核對 zip 內含 sidecar manifest、ffmpeg、whisper、demucs、兩個模型與 cmudict。

## 6. 具體接續步驟

接手後依序執行：

1. 進 `fullstack-code-review` 增量複審本輪 S6-22 變更。
2. Karen 以新 zip `dist/SyllableRepeater-macos-x86_64-unsigned.zip` 解壓後重跑本輪 GUI smoke：首頁開啟課件、設定儲存課件/進度備份、匯出 MP3、錄音/播放錄音。
3. 若 review 或 Karen smoke 發現問題，回到 `fullstack-code-implementation` 開新切片修繕；不要覆寫本輪已產 zip 的 SHA 記錄。

## 7. 拍板事項

- 課件庫是系統首頁。
- 首頁左側開啟課件；右側目前先用文字顯示課件資訊，未來可更動。
- 儲存課件移到設定，與 `.aboprogress` 備份集中在檔案管理區。
- `.abopack` 是課件本體；`.aboprogress` 是進度備份，兩者獨立，只以 lesson id/contentHash 對應。
- 錄音試聽只保留目前步驟記憶體 PCM；磁碟來源檔與一次性播放檔必須刪除。
- Apple Silicon 仍為 Non-scope；release 僅 x86_64。
- 交接檔依使用者要求直接改 04，不新增 05。

## 8. 不要做的事

- 不要把舊 release zip 說成含本輪修繕。
- 不要用旁路繞過 Flutter／Xcode／license／release gate；必要時照工具流程申請權限。
- 不要把 `/usr/local/bin/ffmpeg` GPL build 放進 staging/release。
- 不要弱化 `check_licenses.py`、staging gate、release packaging gate。
- 不要把錄音、API key、絕對路徑寫進 `.aboprogress`、DB、log 或 commit。
- 不要移除 `.aboprogress` 的 M6 updatedAt/contentHash merge 防線。
- 不要動 Apple Silicon、mobile、Windows、server、batch、cloud sync、TTS。
- 不要 revert 或清理與本輪無關的既有工作樹內容。

## 9. 給新 session AI agent 的可複製提示詞

```text
你在 Syllable Repeater repo 接續 S6-22 真 App smoke 修繕。先完整讀 AGENTS.md、
~/Karen_Memory/Dev_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本交接檔與 project memory：
pitfall_record_plugin_lazy_init_indexedstack.md、
workflow_progress_import_export_domain_snapshot_m6.md、
workflow_export_ct03_domain_infra_fp5.md、
workflow_widget_test_real_async_needs_runAsync.md、
workflow_fp6_pack_service_practicegroup_linkage_s6.md。

S6-22 已完成：完整 CI、bundle FFmpeg 實匯出測試、x86_64 release build 與 unsigned zip 均通過。
新 zip 為 dist/SyllableRepeater-macos-x86_64-unsigned.zip，
SHA-256 949c76cfdaf8b0e72702dabecca777110806aa01c7a27c17cc238f9dc12a383c。
下一步請進 fullstack-code-review 增量複審，並安排 Karen 用新 zip 做 GUI smoke。
```

## 10. 接續工作清單

- [x] S6-22.1 課件庫啟動首頁＋左開啟／右資訊。
- [x] S6-22.2 設定檔案管理：儲存課件＋進度備份。
- [x] S6-22.3 匯出全部取消／選取＋實檔存在 gate。
- [x] S6-22.4 錄音 WAV 收尾＋記憶體試聽＋M10 清理。
- [x] S6-22.5 `.aboprogress` ZIP＋`progress.json`。
- [x] S6-22.6 真 exporter test＋完整 CI。
- [x] S6-22.6 x86_64 release app／zip／SHA-256 重建。
- [ ] Karen 以新 zip 重跑本輪 GUI smoke。
- [ ] `fullstack-code-review` 增量複審。
