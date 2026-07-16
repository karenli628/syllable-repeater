// AI-Generate
# Release Checklist — Syllable Repeater macOS v1.1

> 本清單補完 guardrails #50（M9-Extended Engine License Gate）。任何新增
> ASR 引擎或模型在五步完成前，不得進入 release staging、App bundle 或發布包。

## 新引擎／模型上架五步（每個元件各自留證據）

| 步驟 | 必做事項 | 最低證據 | 結果 |
|---|---|---|---|
| 1. Adapter | 建立 Domain port 相容的 infra adapter；不得把平台 API、HTTP 或 sidecar 實作帶進 `packages/domain` | adapter 測試、`domain_purity_test.dart`、變更檔路徑 | ☐ |
| 2. 授權審查 | 在 release license manifest 登錄 `name`、`category`、`license`、`distribution`、`source`、`linking`；sidecar artifact 另須 URL＋SHA-256＋授權三元組 | `check_licenses.py` 與 `fetch_sidecar_artifacts.py` 輸出 PASS | ☐ |
| 3. M4 故障注入 | 驗證 sidecar timeout、非 0 exit、訊號終止／崩潰均經 `SidecarRunner` 映射，App 不被拖垮 | 對應 adapter／`sidecar_runner_test.dart`／錯誤映射測試 | ☐ |
| 4. 金標準回歸 | 以固定金標準音檔跑對齊與練習回歸；11 音節、10 切點、11 步與 M1/M2 不變 | Domain／infra 金標準測試與 benchmark 指令／輸出 | ☐ |
| 5. Registry 註冊 | 在對應 `TranscriberRegistry`／`SyllabifierRegistry` 註冊支援語言；未註冊語言必須 fail-closed | Registry 測試、`ERR_LANGUAGE_UNSUPPORTED` 證據 | ☐ |

### 元件核對表

| 元件／版本 | source | license | SHA-256（若為 artifact） | Adapter／Registry 證據 | M4 證據 | 金標準結果 | 審查人／日期 |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

## 必跑 gate

```bash
# v1.1 沿用既有 release manifest；新增元件先在此檔完成三元組審查，再進 staging。
V11_MANIFEST="spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json"
V11_MATRIX="spec-syllable-repeater/requirements/syllable-practice-macos-v1.1_20260712/guardrails/hard-limits-matrix.md"
V11_DLOG="spec-syllable-repeater/requirements/syllable-practice-macos-v1.1_20260712/guardrails/decision-log.md"

python3 scripts/check_licenses.py "$V11_MANIFEST"
python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py scripts/test_fetch_sidecar_artifacts.py
python3 scripts/check_guardrails.py "$V11_MATRIX" "$V11_DLOG"
flutter test packages/domain/test
flutter test packages/infra/test
flutter analyze packages/domain packages/infra
```

本 v1.1 目前沒有新增實際 ASR 引擎或模型；五步是後續新增元件的必要流程，
不是本輪授權已審查的新依賴清單。正式發布仍須依 v1 release checklist 完成
sidecar staging、release build、封裝與人工 smoke。
