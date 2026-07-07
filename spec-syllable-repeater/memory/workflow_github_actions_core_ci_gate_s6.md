# workflow_github_actions_core_ci_gate_s6

source: syllable-repeater / fullstack-code-implementation S6-12 task 8.2

context: 使用者已建立 GitHub repo `https://github.com/karenli628/syllable-repeater` 並授權 public 以啟用 main branch ruleset。task 8.2 需要把 CT-01～CT-10 的核心自動化測試常駐到遠端 CI。

action: 新增 `.github/workflows/ci.yml` 與 `scripts/ci_core_checks.sh`。CI runner 固定 `macos-15`，Flutter 固定 `3.44.4`，actions 使用 `actions/checkout@v7`、`actions/setup-python@v6`、`subosito/flutter-action@v2`。腳本順序為 `flutter pub get` → `scripts/check_guardrails.py` → `scripts/check_licenses.py` → `python3 -m unittest scripts/test_check_licenses.py` → `flutter test packages/domain/test` → `flutter test packages/infra/test` → `(cd app && flutter test)` → `flutter analyze`。

recommendation: 後續新增核心防線時優先加進 `scripts/ci_core_checks.sh`，讓本機與 GitHub Actions 共用同一條 gate。不要回退到 `macos-latest`；GitHub annotations 已提示 latest migration，使用 `macos-15` 可避免 runner 漂移。8.2 已完成，release 實機 gate 仍屬 9.1/9.2，不要把 release build 綠燈誤寫成已完成。
