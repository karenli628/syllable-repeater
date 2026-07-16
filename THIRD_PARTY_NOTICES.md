# Third-Party Notices

Syllable Repeater 使用以下第三方元件。使用本專案時，請一併遵守各元件之授權條款。發布產物中僅打包已通過授權審查（`scripts/check_licenses.py`，M9）與白名單（MIT / BSD / ISC / Apache-2.0 / LGPL dynamic shared）的元件；GPL / AGPL / non-commercial / research-only 元件不進入 release bundle。

## 已審查通過並打包（sidecar／模型／資料）

| 元件 | 授權 | 說明 |
|------|------|------|
| FFmpeg（自建 shared build） | LGPL-2.1-or-later | 8.1.2 官方 source build，`--disable-gpl --disable-nonfree --enable-libmp3lame --enable-shared`；dynamic linking |
| LAME libmp3lame | LGPL-2.1-or-later | dynamic linking（作 mp3 匯出） |
| whisper.cpp | MIT | Georgi Gerganov；本機 ASR sidecar |
| OpenAI Whisper `small.en` 模型 | MIT | OpenAI 官方以 MIT 發布 |
| demucs.cpp | MIT | sevagh；C++ 實作，用於本機人聲分離 |
| Eigen | MPL-2.0 | demucs.cpp transitive |
| CMUdict | BSD-like | Carnegie Mellon University 發音字典 |

## ⚠️ 授權狀態未獨立確認的元件（bundled sidecar 內含，但法律定性待雙檢）

### htdemucs 預訓練模型權重（`ggml-model-htdemucs-4s-f16.bin`）

- **來源**：`huggingface.co/datasets/Retrobear/demucs.cpp/resolve/main/ggml-model-htdemucs-4s-f16.bin`（Retrobear = demucs.cpp 作者 sevagh 於 Hugging Face 上的別名）
- **原始訓練來源**：Facebook Research 的 `facebookresearch/demucs` 專案 v4 版本
- **manifest 目前標示**：MIT license（沿用 demucs 專案主授權）
- **待確認事項**：**Demucs 原始碼的 MIT License 不得自動套用到預訓練模型權重**。AI 模型權重的授權在法律上可能與程式碼授權獨立（近年常見 CC-BY-NC 4.0 等非商業限制變體）。本專案尚未對此模型權重的獨立授權宣告做過法律審查。
- **待確認前之處置**：
  1. 模型權重檔案（`.local-tools/demucs.cpp/ggml-demucs/ggml-model-htdemucs-4s-f16.bin`）由 `.gitignore` 排除，**不進版本控制、不提交到 GitHub**（現況已符合）
  2. 至獨立授權確認完成前，**Release bundle（`dist/*.zip`）暫停對外散布**——現有 zip 中含此權重約 80MB
  3. 已散布版本（v1 GitHub Release 前提交的產物，若有對外流通）之處置待評估
  4. 未來若確認為 non-commercial 或其他限制型授權，Release 架構需改為由使用者於執行時從官方來源自行下載模型，App 不再打包
- **法律事實核實建議**：
  - 到 `github.com/facebookresearch/demucs` 主專案的 `LICENSE` 檔案確認
  - 檢查 `huggingface.co/facebook/demucs` 或相關 model card 是否對權重有另外聲明
  - 檢查 v4 htdemucs 論文（Rouard et al., 2023）附帶的授權宣告

---

## Dart／Flutter 套件（bundled 但由 pubspec 管理）

| 套件 | 授權 |
|------|------|
| Dart SDK | BSD-3-Clause |
| Flutter SDK | BSD-3-Clause |
| flutter_riverpod | MIT |
| just_audio | MIT |
| record | MIT |
| audio_session | MIT |
| desktop_drop | MIT |
| file_selector | BSD-3-Clause |
| flutter_secure_storage（+ platform / darwin） | BSD-3-Clause |
| http / http_parser | BSD-3-Clause |
| drift / sqlite3 | MIT |
| path | BSD-3-Clause |
| archive | MIT |
| crypto | BSD-3-Clause |
| cupertino_icons | MIT |

完整、機器可驗證的清單見：
`spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json`
（可用 `python3 scripts/check_licenses.py <manifest>` 驗證）

---

## 遠端服務（可選）

| 服務 | 說明 |
|------|------|
| OpenAI Responses API | 使用者選用時，僅供文字翻譯；credential 由使用者自帶，只存於 macOS Keychain，不進版控 |

## 專案本身

Syllable Repeater 本身之原始碼授權見 repository LICENSE 檔案（若尚未建立，請依需要補上）。

## 更新紀錄

- 2026-07-16：建立本檔；記錄 htdemucs 模型權重授權待確認事項，暫停 Release zip 對外散布。
