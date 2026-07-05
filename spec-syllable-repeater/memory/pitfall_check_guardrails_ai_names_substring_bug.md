id: PIT-20260705-check-guardrails-ai-names-substring-bug
type: pitfall
scope: project
source: syllable-repeater / hard-guardrails skill 首輪
context: hard-guardrails skill 提供的 `check_guardrails.py` 範本用 `if any(name in approver for name in AI_NAMES)` 檢查批准人欄是否是 AI（規則 6：AI 不得自批 APPROVED_NOT_APPLICABLE）。使用者的 email 是 `eslite0220@gmail.com`。腳本回報 10 條 APPROVED_NOT_APPLICABLE 全被判違規：「批准人『eslite0220@gmail.com（使用者 2026-07-05 確認）』疑似 AI」。
action: 根因＝`"ai" in "gmail"` 在 Python string 檢查為 True（`gm-**ai**-l` 含 `ai` 子字串）。腳本用「子字串包含」判斷 AI names 太粗，會把 gmail/mail/pain/aim 等任何含 `ai` 的字誤判。修正：改用 word-boundary regex——`re.compile(r"(?<![A-Za-z0-9])(ai|claude|gpt|...)(?![A-Za-z0-9])", re.IGNORECASE)`，只匹配獨立詞不匹配子字串。修完後 10 條 APPROVED 正確通過，只剩 5 條 REJECTED 的預期錯誤。
result: `scripts/check_guardrails.py` 假警報 15 → 0；真警報（5 條 REJECTED 未實作）維持 5 條——這是 skill 鐵律 4 的預期行為，符合設計。腳本規則仍完整。
reasoning: `str in str` 是最基本的 substring test，短英文詞（尤其 `ai`）在英文 email／人名／地名內出現機率極高。腳本 template 為求簡單用了它，本專案 email 恰好觸發。這類 bug 屬 hard-guardrails skill 上游 template 缺陷；本專案先在 local copy 修，未來 skill 遷 Rust 版時應一併修正（rust-guardrail-checker.template）。
recommendation: 未來新增 AI names 到清單也維持 regex `word-boundary` 檢查；不要回頭改用 `in`。若要向 skill 作者回報：template 位置 `~/.claude/skills/hard-guardrails/templates/check_guardrails.py.template` 第 30 行；建議把 `AI_NAMES = {"ai", ...}` 改為 `AI_NAME_PATTERN = re.compile(r"(?<![A-Za-z0-9])(ai|claude|...)(?![A-Za-z0-9])", re.IGNORECASE)` 並改判斷式為 `if AI_NAME_PATTERN.search(approver)`。本專案已在 `scripts/check_guardrails.py` 完成該修法。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
