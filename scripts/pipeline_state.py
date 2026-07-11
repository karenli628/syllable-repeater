# AI-Generate
"""pipeline_state.py — 安全代寫 pipeline-state.md(ai-dev-skills handoff skill 配套)。

替 AI 執行「整檔重寫」步驟,好處:①格式不會壞 ②不用把整檔 30 行重新輸出(省 token)
③schema 在寫入端強制,弱模型只需下參數。跨平台通用(僅需 Python 3)。

用法:
  pipeline_state.py init --project X --requirement Y_20260101 [--path spec-X/…/pipeline-state.md]
  pipeline_state.py set key=value [key=value …]     修改一或多個欄位(整檔按模板重寫)
  pipeline_state.py get [key]                        讀單一欄位;省略 key 印出全部(machine-readable)
  pipeline_state.py show                             人類友善的表格輸出

自動尋找:優先讀 spec-*/handoffs/LATEST.md 的 state_file;找不到再 glob spec-*/requirements/*/pipeline-state.md
(多個時要求 --path 指定)。任何錯誤 exit 1,訊息用繁中且指出「下一動作」。
"""

import argparse
import re
import sys
from datetime import date
from pathlib import Path

SKILLS = {
    "pipeline-navigator", "spec-skills-refresh", "workspace-init",
    "code-knowledge-init", "application-knowledge-init", "business-knowledge-init",
    "prototype-derivation", "requirement-analysis", "hard-guardrails",
    "fullstack-design", "task-split", "fullstack-code-implementation",
    "fullstack-code-review", "project-archive", "ops-monitoring", "handoff",
}
STATE_KEYS = ["schema", "project", "requirement", "stage_skill", "slice", "stage_status",
              "next_skill", "open_tasks", "blocked_reason", "next_patrol_due",
              "last_handoff", "last_updated", "updated_by"]
STATUS_ENUM = {"in_progress", "done", "blocked"}
ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
HEADER = "# pipeline-state(格式固定:只改值,不改鍵、不改行序、不加段落;更新=整檔照本模板重寫)"
FOOTER_COMMENT = """<!-- 欄位規則(本註解隨檔保留,供人與 check_handoff.py 對照;行數上限不計本註解):
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
-->"""

DEFAULTS = {
    "schema": "1", "project": "", "requirement": "",
    "stage_skill": "none", "slice": "none", "stage_status": "in_progress",
    "next_skill": "none", "open_tasks": "none", "blocked_reason": "none",
    "next_patrol_due": "none", "last_handoff": "none",
    "last_updated": str(date.today()), "updated_by": "unknown",
}


def die(msg, fix=""):
    print(f"❌ {msg}", file=sys.stderr)
    if fix:
        print(f"   下一動作:{fix}", file=sys.stderr)
    sys.exit(1)


def parse_state(text):
    kv = {}
    for line in text.splitlines():
        if line.startswith("<!--"):
            break
        m = re.match(r"^([a-z_]+):\s*(.*)$", line.strip())
        if m:
            kv[m.group(1)] = m.group(2).strip()
    return kv


def validate(kv):
    missing = [k for k in STATE_KEYS if k not in kv]
    if missing:
        die(f"缺鍵 {','.join(missing)}", "先跑 `pipeline_state.py init --project X --requirement Y` 建立完整檔")
    if kv["stage_skill"] not in SKILLS | {"none"}:
        die(f"stage_skill={kv['stage_skill']} 不是 16 個 skill 名之一或 none",
            f"用其中之一:{', '.join(sorted(SKILLS))} 或 none")
    if kv["next_skill"] not in SKILLS | {"none"}:
        die(f"next_skill={kv['next_skill']} 不是 16 個 skill 名之一或 none", "同上")
    if kv["stage_status"] not in STATUS_ENUM:
        die(f"stage_status={kv['stage_status']} 不合法", "三選一:in_progress|done|blocked")
    if not ISO_RE.match(kv["last_updated"]):
        die(f"last_updated={kv['last_updated']} 非 YYYY-MM-DD", "改 ISO 日期,例:2026-07-12")
    if kv["next_patrol_due"] != "none" and not ISO_RE.match(kv["next_patrol_due"]):
        die(f"next_patrol_due={kv['next_patrol_due']} 非 YYYY-MM-DD 或 none", "改 ISO 日期或 none")


def render(kv):
    body = "\n".join(f"{k}: {kv[k]}" for k in STATE_KEYS)
    return f"{HEADER}\n{body}\n\n{FOOTER_COMMENT}\n"


def find_state(explicit=None):
    if explicit:
        p = Path(explicit).resolve()
        if not p.exists():
            die(f"{explicit} 不存在", "用 --path 指到正確位置;或先跑 init 建立")
        return p
    latests = sorted(Path.cwd().glob("spec-*/handoffs/LATEST.md"))
    for lp in latests:
        for line in lp.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^state_file:\s*(.+)$", line.strip())
            if m:
                p = (Path.cwd() / m.group(1).strip()).resolve()
                if p.exists():
                    return p
    cands = sorted(Path.cwd().glob("spec-*/requirements/*/pipeline-state.md"))
    if len(cands) == 1:
        return cands[0]
    if len(cands) > 1:
        die("找到多份 pipeline-state.md",
            "用 --path 指定要改哪一份:\n     " + "\n     ".join(str(c) for c in cands))
    die("找不到 pipeline-state.md",
        "先跑 `pipeline_state.py init --project <代號> --requirement <需求目錄>` 建立")


def cmd_init(args):
    if args.path:
        p = Path(args.path).resolve()
    else:
        p = Path.cwd() / f"spec-{args.project}" / "requirements" / args.requirement / "pipeline-state.md"
    if p.exists() and not args.force:
        die(f"{p} 已存在", "確定要覆寫的話加 --force;要改值請用 `set`,不要 init")
    p.parent.mkdir(parents=True, exist_ok=True)
    kv = dict(DEFAULTS)
    kv["project"] = args.project
    kv["requirement"] = args.requirement
    kv["updated_by"] = args.by or "unknown"
    validate(kv)
    p.write_text(render(kv), encoding="utf-8")
    print(f"✅ 已建立 {p.relative_to(Path.cwd()) if p.is_relative_to(Path.cwd()) else p}")
    print(f"   下一步:用 `pipeline_state.py set stage_skill=<某 skill> stage_status=in_progress` 標記當前階段。")


def cmd_set(args):
    p = find_state(args.path)
    kv = parse_state(p.read_text(encoding="utf-8"))
    changes = []
    for pair in args.assignments:
        if "=" not in pair:
            die(f"參數 `{pair}` 不含 =", "格式為 key=value,例如 `stage_status=done`")
        k, v = pair.split("=", 1)
        k, v = k.strip(), v.strip()
        if k not in STATE_KEYS:
            die(f"未知欄位 `{k}`", f"合法欄位:{', '.join(STATE_KEYS)}")
        if kv.get(k) != v:
            changes.append((k, kv.get(k, "(空)"), v))
            kv[k] = v
    if "last_updated" not in [c[0] for c in changes]:
        today = str(date.today())
        if kv.get("last_updated") != today:
            changes.append(("last_updated", kv.get("last_updated", "(空)"), today))
            kv["last_updated"] = today
    if args.by and kv.get("updated_by") != args.by:
        changes.append(("updated_by", kv.get("updated_by", "(空)"), args.by))
        kv["updated_by"] = args.by
    validate(kv)
    p.write_text(render(kv), encoding="utf-8")
    if not changes:
        print("(沒有變化)")
        return
    print(f"✅ 已更新 {p.relative_to(Path.cwd()) if p.is_relative_to(Path.cwd()) else p}")
    for k, old, new in changes:
        print(f"   {k}: {old} → {new}")


def cmd_get(args):
    p = find_state(args.path)
    kv = parse_state(p.read_text(encoding="utf-8"))
    if args.key:
        if args.key not in STATE_KEYS:
            die(f"未知欄位 `{args.key}`", f"合法欄位:{', '.join(STATE_KEYS)}")
        print(kv.get(args.key, ""))
    else:
        for k in STATE_KEYS:
            print(f"{k}={kv.get(k, '')}")


def cmd_show(args):
    p = find_state(args.path)
    kv = parse_state(p.read_text(encoding="utf-8"))
    print(f"📄 {p}\n")
    for k in STATE_KEYS:
        print(f"  {k:20s} {kv.get(k, '')}")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(
        description="pipeline-state.md 安全代寫(格式強制、跨平台、省 token)。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="範例:\n"
               "  pipeline_state.py init --project syllable-repeater --requirement req_20260101\n"
               "  pipeline_state.py set stage_skill=fullstack-design stage_status=in_progress\n"
               "  pipeline_state.py set stage_status=done next_skill=task-split open_tasks=none\n"
               "  pipeline_state.py get stage_skill\n"
               "  pipeline_state.py show",
    )
    ap.add_argument("--path", help="pipeline-state.md 路徑(省略時自動尋找)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init", help="從模板建立新的 pipeline-state.md")
    p_init.add_argument("--project", required=True, help="專案代號,例如 syllable-repeater")
    p_init.add_argument("--requirement", required=True, help="需求目錄名,例如 req_20260101")
    p_init.add_argument("--by", help="updated_by 欄位(工具名)")
    p_init.add_argument("--force", action="store_true", help="檔案已存在時覆寫")
    p_init.set_defaults(func=cmd_init)

    p_set = sub.add_parser("set", help="修改一或多個欄位(整檔按模板重寫)")
    p_set.add_argument("assignments", nargs="+", metavar="key=value")
    p_set.add_argument("--by", help="順便更新 updated_by")
    p_set.set_defaults(func=cmd_set)

    p_get = sub.add_parser("get", help="讀單一欄位或全部(machine-readable)")
    p_get.add_argument("key", nargs="?")
    p_get.set_defaults(func=cmd_get)

    p_show = sub.add_parser("show", help="人類友善的表格輸出")
    p_show.set_defaults(func=cmd_show)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
