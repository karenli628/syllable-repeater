#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_guardrails.py — 硬性限制檢查腳本（早期 bootstrap 版）

定位：這是啟動用腳本（bootstrap script），目的是讓零程式基礎者先快速建立
「清單不可空白、不適用要寫理由、AI 不能跳過」的最小可行檢查。
規則穩定後，應遷移為 tools/guardrail-checker/ 內的 Rust-based guardrail checker。

用法：
    python3 scripts/check_guardrails.py <hard-limits-matrix.md 路徑> [decision-log.md 路徑]

退出碼：0 = 通過；1 = 檢查失敗（CI 據此阻擋交付）。
"""

import re
import sys

LEGAL_STATUSES = {
    "NOT_REVIEWED",
    "IMPLEMENTED",
    "PARTIAL",
    "NOT_APPLICABLE_PENDING_HUMAN_REVIEW",
    "APPROVED_NOT_APPLICABLE",
    "BLOCKED",
    "REJECTED_NEEDS_IMPLEMENTATION",
}

# 這些字樣出現在批准人欄，視為 AI 自行批准 → 違規。
# 用 word-boundary regex 檢查，避免 email 內 "gmail" 的 "ai" 子字串被誤判。
_AI_NAMES = ("ai", "claude", "gpt", "chatgpt", "codex", "kiro", "copilot", "gemini", "assistant")
AI_NAME_PATTERN = re.compile(
    r"(?<![A-Za-z0-9])(" + "|".join(_AI_NAMES) + r")(?![A-Za-z0-9])",
    re.IGNORECASE,
)


def parse_matrix_rows(text):
    """解析 matrix 表格列：| # | 限制 | 白話說明 | 狀態 | 落地位置 | 批准人 | 備註 |"""
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        # 至少 7 欄且第一欄是數字才是資料列
        if len(cells) >= 7 and re.fullmatch(r"\d+", cells[0]):
            rows.append({
                "no": cells[0],
                "name": cells[1],
                "status": cells[3],
                "location": cells[4],
                "approver": cells[5],
                "note": cells[6],
            })
    return rows


def main():
    if len(sys.argv) < 2:
        print("用法：python3 check_guardrails.py <hard-limits-matrix.md> [decision-log.md]")
        return 1

    matrix_path = sys.argv[1]
    log_path = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        with open(matrix_path, encoding="utf-8") as f:
            matrix_text = f.read()
    except OSError as e:
        print(f"❌ 無法讀取 matrix：{e}")
        return 1

    log_text = ""
    if log_path:
        try:
            with open(log_path, encoding="utf-8") as f:
                log_text = f.read()
        except OSError as e:
            print(f"❌ 無法讀取 decision-log：{e}")
            return 1

    rows = parse_matrix_rows(matrix_text)
    errors = []
    warnings = []

    if not rows:
        errors.append("matrix 中找不到任何限制資料列（表格格式是否被改壞？）")

    for r in rows:
        label = f"#{r['no']} {r['name']}"
        status = r["status"]

        # 1) 狀態必須合法
        if status not in LEGAL_STATUSES:
            errors.append(f"{label}：狀態「{status}」不是合法狀態值")
            continue

        # 2) 不得殘留 NOT_REVIEWED
        if status == "NOT_REVIEWED":
            errors.append(f"{label}：仍是 NOT_REVIEWED——每一項都必須有結論")

        # 3) IMPLEMENTED 必須有落地位置
        if status == "IMPLEMENTED" and not r["location"]:
            errors.append(f"{label}：IMPLEMENTED 但「落地位置」是空的——沒有落地檔案就不算實作")

        # 4) PARTIAL 必附風險說明
        if status == "PARTIAL" and not r["note"]:
            errors.append(f"{label}：PARTIAL 但備註欄沒有風險說明與補完計畫")

        # 5) 待人類批准的必須有 decision-log 紀錄
        if status == "NOT_APPLICABLE_PENDING_HUMAN_REVIEW":
            dl_ref = re.search(r"DL-\d+", r["note"])
            if not dl_ref:
                errors.append(f"{label}：不適用但備註欄沒有 decision-log 編號（DL-xxx）")
            elif log_text and dl_ref.group(0) not in log_text:
                errors.append(f"{label}：引用的 {dl_ref.group(0)} 在 decision-log 中不存在")
            warnings.append(f"{label}：等待人類批准中")

        # 6) 已批准不適用：批准人必填且不得是 AI
        if status == "APPROVED_NOT_APPLICABLE":
            approver = r["approver"]
            if not approver:
                errors.append(f"{label}：APPROVED_NOT_APPLICABLE 但批准人是空的——AI 不得自行批准")
            elif AI_NAME_PATTERN.search(approver):
                errors.append(f"{label}：批准人「{approver}」疑似 AI——不適用只能由人類批准")

        # 7) 被拒絕的必須實作
        if status == "REJECTED_NEEDS_IMPLEMENTATION":
            errors.append(f"{label}：人類已拒絕不適用理由，要求實作——實作完成前不得交付")

        # 8) BLOCKED 提醒
        if status == "BLOCKED":
            warnings.append(f"{label}：BLOCKED——缺少資訊，請儘快向使用者取得")

    # decision-log 中不得有 AI 自填的批准
    for m in re.finditer(r"人類裁決.*?：.*?`?(APPROVED[^`\n]*)`?", log_text):
        pass  # 批准本身合法；是否 AI 自填由上面的批准人欄與 git 紀錄把關

    print("=" * 60)
    print("硬性限制檢查報告（bootstrap 版）")
    print("=" * 60)
    print(f"限制項總數：{len(rows)}")
    status_count = {}
    for r in rows:
        status_count[r["status"]] = status_count.get(r["status"], 0) + 1
    for s, c in sorted(status_count.items()):
        print(f"  {s}: {c}")
    print("-" * 60)

    if warnings:
        print(f"⚠️ 提醒 {len(warnings)} 項：")
        for w in warnings:
            print(f"  ⚠️ {w}")
    if errors:
        print(f"❌ 違規 {len(errors)} 項：")
        for e in errors:
            print(f"  ❌ {e}")
        print("-" * 60)
        print("結果：不通過——交付被阻擋。請逐項處理後重跑。")
        return 1

    print("結果：✅ 通過。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
