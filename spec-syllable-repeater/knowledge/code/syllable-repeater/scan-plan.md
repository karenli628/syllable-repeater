// AI-Generate
---
project: syllable-repeater
scan_date: 2026-07-08
git_commit: 8cf46ddc724b61242d926a8d495397db40e0c187
scan_type: full
---

# scan-plan

## 專案屬性判定

本專案是 Flutter macOS 桌面 App + Dart workspace 的本機一體化專案，不是伺服器型後端專案。前端入口位於 `app/lib/`；後端視角由 `packages/domain/` 純 Dart 領域層、`packages/infra/` sidecar/DB/檔案 IO adapter、macOS app 內的 Riverpod provider 接線共同構成。

## 掃描策略

| 序號 | 掃描項 | 命中規則 | 掃描範圍 | 預估目標數 | 策略 | 狀態 | 實際產出數 |
|---:|---|---|---|---:|---|---|---:|
| 1 | 前端 Flutter UI 模組掃描 | `app/lib/features/**`、`app/lib/shell/**`、`app/lib/shared/**` | `app/lib` | 32 檔 | AI 直接掃描 | DONE | 7 個功能模組 |
| 2 | 後端領域/infra 模組掃描 | `packages/domain/lib`、`packages/infra/lib`、workspace `pubspec.yaml` | `packages/domain/lib` 37 檔、`packages/infra/lib` 18 檔 | 55 檔 | AI 直接掃描 | DONE | 9 個後端模組 |
| 3 | 介面/入口契約掃描 | Dart exports、abstract ports、Riverpod providers、sidecar wrapper | `packages/domain/lib/domain.dart`、`app/lib/shared/infra/**`、`packages/infra/lib/src/**` | 0 HTTP Controller | AI 直接掃描 | DONE | 0 REST API、16 組內部契約 |
| 4 | 資料模型掃描 | `CREATE TABLE`、Drift `Table` | `packages/infra/lib/db/schema/*.sql`、`app_database.dart` | 6 表 | DDL + Drift 交叉核對 | DONE | 6 表全量 |
| 5 | 外部依賴掃描 | `http.Client`、`Process.start`、File/Directory、Keychain、Flutter plugins | `app/lib`、`packages/infra/lib`、`pubspec.yaml` | 9 類依賴 | AI 直接掃描 | DONE | 10 類依賴 |

## 合理性檢查

- 涵蓋率：前端 `app/lib` 32 檔、domain 37 檔、infra 18 檔皆納入模組掃描。
- 型別純度：未將 Flutter widget test、generated Drift 檔案或 release staging binaries 當作業務入口；`app_database.g.dart` 僅用於與 Drift schema 名稱交叉核對。
- 欄位完整度：資料表以 DDL + Drift table 定義交叉核對，6 張表全量列出。
- 偏差：本專案無 Spring Controller/REST API，因此 `backend-interface.md` 明確列 0 個 HTTP 對外介面，改列 Dart ports/providers/sidecar contracts 作為本機應用內部契約。

