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

## htdemucs 預訓練模型權重（`ggml-model-htdemucs-4s-f16.bin`）：授權狀態與處置決策（2026-07-16 定案）

### 來源
- **打包來源**：`huggingface.co/datasets/Retrobear/demucs.cpp/resolve/main/ggml-model-htdemucs-4s-f16.bin`（Retrobear = demucs.cpp 作者 sevagh 於 Hugging Face 上的別名，將原始權重轉為 ggml 格式）
- **原始訓練來源**：Facebook Research（Meta Platforms, Inc. and affiliates）的 `facebookresearch/demucs` 專案 v4 版本

### 已完成的授權事實查證（2026-07-16 由使用者主導）

| 查證項目 | 結果 |
|----------|------|
| `facebookresearch/demucs` 主專案 LICENSE | MIT License（Meta Platforms, Inc. and affiliates） |
| 主專案 README 是否有模型權重的獨立授權聲明 | **無**（AI 抓取實測） |
| 主專案是否有單獨的 MODEL_LICENSE 檔案 | **無** |
| 主專案是否含 non-commercial 字樣或商業限制 | **無** |
| `huggingface.co/facebook/demucs` 官方 model card | **404**（Meta 未在 HF 建立官方頁） |
| 主專案 README 維護狀態 | 明示「不再維護」，指向替代倉庫 |
| 訓練資料集 | MUSDB HQ ＋ 額外 800 首歌曲 |
| MUSDB18-HQ 資料集本身授權 | CC BY-NC-SA 4.0（**非商業**、共享相同方式）——**注意**：主流法律學說「訓練資料授權不自動繼承到模型權重」，但生成式 AI 領域此議題有活躍訴訟先例（如 Getty Images v. Stability AI），尚無終審結論 |

### 使用者的處置決策（2026-07-16）

**選擇：保持現狀——bundled 但不對外散布**

理由：使用者當前用途為個人本機使用，無商業散布意圖；MIT 主授權涵蓋模型權重雖為主流業界慣例，但訓練資料授權議題仍屬法律灰色地帶。保守做法在無成本情境下最合理。

具體處置：
1. **模型權重檔**（`.local-tools/demucs.cpp/ggml-demucs/ggml-model-htdemucs-4s-f16.bin`）由 `.gitignore` 排除，不進版本控制、不上 GitHub（現況已符合）
2. **Release zip**（`dist/SyllableRepeater-macos-x86_64-unsigned.zip`，含 htdemucs 權重 80MB）僅供本機使用，**不對外散布**：
   - 不上 GitHub Release
   - 不用任何方式分發給第三方（含免費散布）
   - 若他人詢問，說明「基於謹慎，暫不提供公開下載」
3. 若未來意圖改變（例如想商業化或公開散布），必須先重新檢視此決策；建議屆時：
   - 選項 A：諮詢律師確認 MIT 是否涵蓋模型權重
   - 選項 B：改為 App 執行期由使用者自行從官方來源下載模型（Release 不打包）——屬 v1.2+ 架構重構工作量
4. 本檔案作為決策紀錄留檔；未來若 Meta 對 demucs 模型權重發布任何獨立聲明，可回頭更新此段。

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

- 2026-07-16（早）：建立本檔；記錄 htdemucs 模型權重授權待確認事項，暫停 Release zip 對外散布。
- 2026-07-16（晚）：完成使用者主導的授權事實查證（Facebook demucs 主 LICENSE = MIT、README 無獨立模型聲明、HF 無官方 model card、訓練資料 MUSDB HQ 為 CC BY-NC-SA 4.0）。使用者定案「保持 bundled 但不對外散布」，理由為個人本機使用無商業意圖、保守做法在無成本情境下最合理。
