# AI-Generate
"""check_handoff.py — 交接檔/pipeline-state/LATEST 硬閘門檢查器(ai-dev-skills handoff skill 配套)。

模式:
  --staged   pre-commit 用:staged 含 spec-*/handoffs/ 或 pipeline-state.md 時逐項驗證,不過就擋 commit。
  --latest   handoff skill 寫完自跑:驗最新交接檔+LATEST+state 的一致性。
  --all      CI 用:驗所有新格式交接檔+state/LATEST schema+BOOT-BLOCK。
  --file P   驗單一交接檔的內容格式(不做跨檔綁定)。

判定:任何 ❌ → exit 1,末行印 `check_handoff: FAIL`;全過 → exit 0,末行印 `check_handoff: PASS`。
遷移期豁免:無「> 型別:」聲明行的交接檔視為舊格式史料,跳過內容檢查(--staged 中「新增」的交接檔必須是新格式)。
"""

import re
import subprocess
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
CODES = {"CTX", "USER", "BLOCK", "SLICE"}
NAME_RE = re.compile(r"^交接檔-\d{8}-\d{2}-[a-z][a-z0-9-]*_.+\.md$")
FORBID_RE = re.compile(r"(拷貝|copy|_bak|備份|_new|_old)", re.IGNORECASE)
TYPE_RE = re.compile(
    r">\s*型別\s*[:：]\s*(完成型|中斷型\s*[（(]\s*代碼\s*[:：]\s*(CTX|USER|BLOCK|SLICE)\s*[）)])"
)
SUFFIX_RE = re.compile(r"_中斷(CTX|USER|BLOCK|SLICE)\.md$")
ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
# 交接檔新規範上線日:此日以前的檔案即使首次 add 亦視為史料,豁免流水號與型別聲明強制
# (規範文件已承諾,程式碼補齊。2026-07-12 使用者裁定六份舊檔均屬完成型史料)
LEGACY_HANDOFF_CUTOFF = "20260712"


def is_legacy_handoff(name):
    m = re.match(r"^交接檔-(\d{8})-", name)
    return m is not None and m.group(1) < LEGACY_HANDOFF_CUTOFF
STATE_KEYS = ["schema", "project", "requirement", "stage_skill", "slice", "stage_status",
              "next_skill", "open_tasks", "blocked_reason", "next_patrol_due",
              "last_handoff", "last_updated", "updated_by"]
LATEST_KEYS = ["schema", "latest_handoff", "type", "state_file"]
LATEST_TYPES = {"done", "interrupted-CTX", "interrupted-USER", "interrupted-BLOCK", "interrupted-SLICE"}


class Report:
    def __init__(self):
        self.errors, self.warnings, self.oks = [], [], []

    def err(self, msg, fix):
        self.errors.append(f"❌ {msg}\n   下一動作:{fix}")

    def warn(self, msg):
        self.warnings.append(f"⚠️ {msg}")

    def ok(self, msg):
        self.oks.append(f"✅ {msg}")

    def finish(self):
        for m in self.oks:
            print(m)
        for m in self.warnings:
            print(m)
        for m in self.errors:
            print(m)
        status = "FAIL" if self.errors else "PASS"
        print(f"check_handoff: {status}")
        return 1 if self.errors else 0


def sh(args, cwd=None):
    if args and args[0] == "git":
        args = ["git", "-c", "core.quotepath=false"] + args[1:]  # 中文檔名不被八進位跳脫
    p = subprocess.run(args, capture_output=True, text=True, cwd=cwd)
    return p.returncode, p.stdout, p.stderr


def repo_root():
    rc, out, _ = sh(["git", "rev-parse", "--show-toplevel"])
    return Path(out.strip()) if rc == 0 else Path.cwd()


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def parse_kv(text):
    kv, order = {}, []
    for line in strip_comments(text).splitlines():
        m = re.match(r"^([a-z_]+):\s*(.*)$", line.strip())
        if m:
            kv[m.group(1)] = m.group(2).strip()
            order.append(m.group(1))
    return kv, order


def sections(text):
    """回傳 {段號: 段內文};段=## N. 標題起至下一個 ## N. 前。"""
    out, cur, buf = {}, None, []
    for line in text.splitlines():
        m = re.match(r"^##\s*(\d+)\.", line)
        if m:
            if cur is not None:
                out[cur] = "\n".join(buf)
            cur, buf = int(m.group(1)), []
        elif cur is not None:
            buf.append(line)
    if cur is not None:
        out[cur] = "\n".join(buf)
    return out


def handoff_type(text):
    """回傳 ('done', None) / ('interrupted', 代碼) / (None, None)=舊格式。"""
    for line in text.splitlines()[:15]:
        m = TYPE_RE.search(line)
        if m:
            if m.group(1).startswith("完成型"):
                return "done", None
            return "interrupted", m.group(2)
    return None, None


def porcelain_entries(root):
    _, out, _ = sh(["git", "status", "--porcelain"], cwd=root)
    return [l for l in out.splitlines() if l.strip()]


def dirty_besides(root, allowed_paths):
    """porcelain 中不屬 allowed_paths(相對路徑)且非「純 staged」的項目。"""
    bad = []
    for l in porcelain_entries(root):
        x, y, path = l[0], l[1], l[3:].strip().strip('"')
        if " -> " in path:
            path = path.split(" -> ")[-1]
        if path in allowed_paths:
            continue
        if x in "MADRC" and y == " ":
            continue  # 純 staged,屬本次 commit
        bad.append(l)
    return bad


def find_task_split(root, state_path):
    p = state_path.parent / "task" / "task-split.md"
    return p if p.exists() else None


def task_status_in_split(split_text, task_id):
    """回傳 'x'(已勾)/'o'(未勾)/None(找不到)。"""
    esc = re.escape(task_id)
    if re.search(r"-\s*\[x\][^\n]*(?:任務|task|Task|`|\s)" + esc + r"(?![\d.])", split_text):
        return "x"
    if re.search(r"-\s*\[ \][^\n]*(?:任務|task|Task|`|\s)" + esc + r"(?![\d.])", split_text):
        return "o"
    return None


def claimed_ids(sec5_text):
    ids = set()
    for m in re.finditer(r"(?:task-split|任務)\s*`?([0-9]+(?:\.[0-9]+)+|[0-9]+\.[0-9]+)`?", sec5_text):
        ids.add(m.group(1))
    return ids


def unchecked_items(sec10_text):
    return [l for l in sec10_text.splitlines() if re.match(r"^\s*-\s*\[ \]", l)]


# ---------- 檢查群 ----------

def check_name_and_place(rep, path, root, is_new):
    rel = path.relative_to(root)
    name = path.name
    if FORBID_RE.search(name):
        rep.err(f"{name}:檔名含副本禁字", "改名;要留舊版用 handoffs/archive/ 或 git 歷史")
    parts = rel.parts
    in_handoffs = len(parts) >= 3 and parts[0].startswith("spec-") and parts[1] == "handoffs"
    if not in_handoffs:
        rep.err(f"{rel}:交接檔不在 spec-*/handoffs/ 之下", "搬到 spec-<專案代號>/handoffs/")
    elif "drafts" in parts:
        rep.err(f"{rel}:drafts/ 草稿不得 commit", "定稿後搬出 drafts/ 再 commit")
    if is_new and not NAME_RE.match(name):
        rep.err(f"{name}:新交接檔檔名不符規則(交接檔-yyyymmdd-NN-<skill>_…)",
                "照 handoff-naming-convention.md 重新命名(含 -NN- 流水號)")


def check_content(rep, path, text, root):
    """回傳 (type, code, secs);舊格式回傳 (None,None,None)。"""
    htype, code = handoff_type(text)
    name = path.name
    if htype is None:
        rep.warn(f"{name}:無型別聲明行,視為舊格式史料,跳過內容檢查(遷移期豁免)")
        return None, None, None
    m = SUFFIX_RE.search(name)
    if htype == "interrupted" and (not m or m.group(1) != code):
        rep.err(f"{name}:中斷型(代碼 {code})檔名缺 `_中斷{code}` 尾綴", "檔名補尾綴,與內文型別雙向一致")
    if htype == "done" and m:
        rep.err(f"{name}:完成型檔名不得帶 `_中斷` 尾綴", "改型別或改檔名")
    secs = sections(text)
    missing = [str(n) for n in range(1, 11) if n not in secs]
    if missing:
        rep.err(f"{name}:缺段落 {','.join(missing)}(9+1 段必須齊全)", "照 handoff-template.md 補齊")
        return htype, code, secs
    nums = [n for n in sorted(secs) if 1 <= n <= 10]
    if nums != sorted(nums):
        rep.err(f"{name}:段落順序錯誤", "照 1→10 排列")
    for n in (7, 8):
        if not secs.get(n, "").strip():
            rep.err(f"{name}:第 {n} 段空白", "空時明寫「無」")
    s9 = secs.get(9, "")
    fence = re.search(r"```text\n(.*?)```", s9, re.DOTALL)
    if not fence:
        rep.err(f"{name}:第 9 段缺 ```text fenced block", "放入 3 行固定 fallback 提示詞")
    else:
        if len([l for l in fence.group(1).splitlines() if l.strip()]) > 4:
            rep.err(f"{name}:第 9 段 fallback 超過 4 行(應為固定 3 行)", "改回固定內容;客製資訊由 LATEST/state 承載")
    if "/Users/" in s9 or "C:\\" in s9:
        rep.err(f"{name}:第 9 段夾帶絕對路徑(應為固定內容)", "路徑資訊放第 3 段與 LATEST.md")
    if htype == "interrupted":
        decl = re.search(r"未完成中斷[^\n]*完成下方\s*(\d+)\s*項", text)
        items = unchecked_items(secs.get(10, ""))
        if not decl:
            rep.err(f"{name}:中斷型缺置頂自我聲明(「本交接檔為未完成中斷——…完成下方 N 項」)",
                    "在型別聲明行補上,N=第 10 段未勾項數")
        elif int(decl.group(1)) != len(items):
            rep.err(f"{name}:置頂聲明 N={decl.group(1)} 但第 10 段未勾項={len(items)}", "兩者對齊")
        if code == "USER" and not re.search(r"使用者原話\s*[:：]\s*「", text):
            rep.err(f"{name}:USER 代碼缺「使用者原話:「…」」引用", "逐字引用使用者要求中斷的原話")
        if code == "BLOCK" and "已嘗試的替代方案" not in text:
            rep.err(f"{name}:BLOCK 代碼缺錯誤證據(「已嘗試的替代方案」)", "附錯誤輸出尾 3 行+替代方案一行")
        if code == "CTX":
            for l in items:
                if "`" not in l:
                    rep.err(f"{name}:CTX 剩餘清單項缺下一步指令:{l.strip()[:40]}", "每項附一行可執行指令(反引號圍住)")
                    break
    return htype, code, secs


def check_ctx_budget(rep, path, text):
    m = re.match(r"^交接檔-(\d{8})-", path.name)
    if not m or "_中斷CTX" not in path.name:
        return
    same_day = [p for p in path.parent.glob(f"交接檔-{m.group(1)}-*_中斷CTX*.md")]
    if len(same_day) >= 2 and "escalation:" not in text:
        rep.err(f"{path.name}:同日第 {len(same_day)} 份 CTX 中斷檔,缺 `escalation:` 欄",
                "加一行 escalation: 向使用者說明連續中斷的原因")


def check_binding(rep, handoff_path, htype, code, secs, root, require_staged):
    """LATEST/state 同步與 task-split 交叉核。"""
    hdir = handoff_path.parent
    latest_p = hdir / "LATEST.md"
    if not latest_p.exists():
        rep.err("handoffs/LATEST.md 不存在", "照 handoff/templates/LATEST.md.template 建立並指向本檔")
        return
    lkv, _ = parse_kv(latest_p.read_text(encoding="utf-8"))
    if Path(lkv.get("latest_handoff", "")).name != handoff_path.name:
        rep.err(f"LATEST.latest_handoff({Path(lkv.get('latest_handoff','')).name})≠最新交接檔({handoff_path.name})",
                "整檔重寫 LATEST.md 指向本檔(與交接檔同一個 commit)")
    want = "done" if htype == "done" else f"interrupted-{code}"
    if lkv.get("type") != want:
        rep.err(f"LATEST.type={lkv.get('type')} 應為 {want}", "LATEST.md 的 type 與交接檔型別對齊")
    state_p = root / lkv.get("state_file", "")
    if not state_p.exists():
        rep.err(f"state_file 指向的 {lkv.get('state_file')} 不存在", "照 pipeline-state.md.template 建立")
        return
    skv, _ = parse_kv(state_p.read_text(encoding="utf-8"))
    if skv.get("last_handoff") != handoff_path.name:
        rep.err(f"pipeline-state.last_handoff≠本交接檔名", "handoff skill 步驟 2:更新 last_handoff 欄")
    hdate = re.match(r"^交接檔-(\d{8})-", handoff_path.name)
    if hdate:
        iso = f"{hdate.group(1)[:4]}-{hdate.group(1)[4:6]}-{hdate.group(1)[6:]}"
        if skv.get("last_updated", "") < iso:
            rep.err(f"pipeline-state.last_updated({skv.get('last_updated')})早於交接檔日期({iso})",
                    "收尾掛接第 2 步:整檔重寫 state 再交接")
    if skv.get("stage_skill", "") not in secs.get(4, "") and skv.get("stage_skill") != "none":
        rep.warn(f"交接檔第 4 段未提及 state.stage_skill={skv.get('stage_skill')}(請確認兩者一致)")
    split_p = find_task_split(root, state_p)
    if split_p is None:
        rep.warn("找不到 task/task-split.md,跳過任務交叉核")
    else:
        split = split_p.read_text(encoding="utf-8")
        if htype == "done" or code == "SLICE":
            for tid in sorted(claimed_ids(secs.get(5, ""))):
                st = task_status_in_split(split, tid)
                if st == "o":
                    rep.err(f"第 5 段宣稱完成 {tid},但 task-split 仍為 `- [ ]`(假完成)",
                            "回去完成該任務並勾選;或改中斷型並移出完成清單")
                elif st is None:
                    rep.warn(f"第 5 段的任務編號 {tid} 在 task-split 找不到,請人工確認")
        if htype == "interrupted":
            for l in unchecked_items(secs.get(10, "")):
                m = re.search(r"`?([0-9]+\.[0-9]+)`?", l)
                if m and task_status_in_split(split, m.group(1)) == "x":
                    rep.err(f"第 10 段未勾項 {m.group(1)} 在 task-split 已是 `- [x]`(帳不一致)",
                            "對齊兩處勾選狀態")
    if require_staged:
        _, out, _ = sh(["git", "diff", "--cached", "--name-only"], cwd=root)
        staged = set(out.splitlines())
        for need in (str(latest_p.relative_to(root)), str(state_p.relative_to(root))):
            if need not in staged:
                rep.err(f"{need} 未與交接檔同一個 commit staged", "git add 後再 commit(同 commit 綁定)")
    allowed = {str(handoff_path.relative_to(root)),
               str(latest_p.relative_to(root)),
               str(state_p.relative_to(root))}
    if htype == "done" or code == "CTX":
        bad = dirty_besides(root, allowed)
        if bad:
            label = "完成型要求除本次交接外樹乾淨" if htype == "done" else "CTX 要求先做 WIP commit"
            rep.err(f"{label},但仍有 {len(bad)} 項未收變更(如 {bad[0][:60]})",
                    "完成型:先把變更 commit;CTX:先 `git add -A && git commit -m \"wip: <切片> 中斷存檔\"`")


def check_frozen(rep, root):
    _, out, _ = sh(["git", "diff", "--cached", "--name-status", "--diff-filter=M"], cwd=root)
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        path = parts[-1].strip('"')
        if "/handoffs/" not in path or not Path(path).name.startswith("交接檔-"):
            continue
        rc_old, old, _ = sh(["git", "show", f"HEAD:{path}"], cwd=root)
        rc_new, new, _ = sh(["git", "show", f":{path}"], cwd=root)
        if rc_old != 0 or rc_new != 0:
            continue
        if not new.startswith(old):
            rep.err(f"{path}:已 commit 的交接檔被就地改寫(凍結規則)",
                    "還原原文;現況更新寫 pipeline-state.md;補充只能追加「## 後記(yyyy-mm-dd)」段")
        elif new[len(old):].lstrip("\n") and not new[len(old):].lstrip("\n").startswith("## 後記"):
            rep.err(f"{path}:追加內容未以「## 後記」開頭(凍結規則)", "補「## 後記(yyyy-mm-dd)」標題")


def check_state_schema(rep, state_p, root):
    text = state_p.read_text(encoding="utf-8")
    body_lines = [l for l in strip_comments(text).splitlines() if l.strip()]
    if len(body_lines) > 30:
        rep.err(f"{state_p.name}:正文 {len(body_lines)} 行 >30", "state 只存指標與編號,不抄內文")
    kv, order = parse_kv(text)
    missing = [k for k in STATE_KEYS if k not in kv]
    if missing:
        rep.err(f"{state_p.name}:缺鍵 {','.join(missing)}", "照 pipeline-state.md.template 整檔重寫(只改值)")
        return
    if [k for k in order if k in STATE_KEYS] != STATE_KEYS:
        rep.err(f"{state_p.name}:鍵順序與模板不符", "整檔照模板重寫,不改行序")
    for k in ("stage_skill", "next_skill"):
        if kv[k] not in SKILLS | {"none"}:
            rep.err(f"{state_p.name}:{k}={kv[k]} 不是 16 個 skill 名之一或 none", "改為合法 skill 名")
    if kv["stage_status"] not in {"in_progress", "done", "blocked"}:
        rep.err(f"{state_p.name}:stage_status={kv['stage_status']} 不合法", "in_progress|done|blocked 三選一")
    if not ISO_RE.match(kv["last_updated"]):
        rep.err(f"{state_p.name}:last_updated 非 YYYY-MM-DD", "改 ISO 日期")
    if kv["next_patrol_due"] != "none" and not ISO_RE.match(kv["next_patrol_due"]):
        rep.err(f"{state_p.name}:next_patrol_due 非 YYYY-MM-DD|none", "改 ISO 日期或 none")
    if kv["open_tasks"] not in {"none", "10+"}:
        split_p = find_task_split(root, state_p)
        if split_p:
            split = split_p.read_text(encoding="utf-8")
            for tid in [t.strip() for t in kv["open_tasks"].split(",") if t.strip()]:
                st = task_status_in_split(split, tid)
                if st == "x":
                    rep.err(f"{state_p.name}:open_tasks 含已完成任務 {tid}", "收尾掛接第 2 步:重寫 open_tasks")
                elif st is None:
                    rep.warn(f"{state_p.name}:open_tasks 的 {tid} 在 task-split 找不到")


def check_latest_schema(rep, latest_p, root):
    kv, order = parse_kv(latest_p.read_text(encoding="utf-8"))
    missing = [k for k in LATEST_KEYS if k not in kv]
    if missing:
        rep.err(f"{latest_p}:缺鍵 {','.join(missing)}", "照 LATEST.md.template 整檔重寫")
        return
    if kv["type"] not in LATEST_TYPES:
        rep.err(f"{latest_p}:type={kv['type']} 不合法", "done|interrupted-CTX|USER|BLOCK|SLICE")
    hp = root / kv["latest_handoff"]
    if not hp.exists():
        rep.err(f"{latest_p}:latest_handoff 指向的檔案不存在", "指向真實存在的最新交接檔")
    sp = root / kv["state_file"]
    if not sp.exists():
        rep.err(f"{latest_p}:state_file 指向的檔案不存在", "照 pipeline-state.md.template 建立")
    else:
        check_state_schema(rep, sp, root)


def check_boot_block(rep, root):
    blocks = {}
    for name in ("CLAUDE.md", "AGENTS.md"):
        p = root / name
        if not p.exists():
            continue
        lines = p.read_text(encoding="utf-8").splitlines()
        first = next((l for l in lines if l.strip()), "")
        if "BOOT-BLOCK v1 BEGIN" not in first:
            rep.err(f"{name}:BOOT-BLOCK BEGIN 不在檔首", "把 <!-- BOOT-BLOCK v1 BEGIN --> 區塊移到檔案最前")
            continue
        try:
            b = lines.index(next(l for l in lines if "BOOT-BLOCK v1 BEGIN" in l))
            e = lines.index(next(l for l in lines if "BOOT-BLOCK v1 END" in l))
        except StopIteration:
            rep.err(f"{name}:缺 BOOT-BLOCK END 標記", "補 <!-- BOOT-BLOCK v1 END -->")
            continue
        inner = lines[b + 1:e]
        if len(inner) > 20:
            rep.err(f"{name}:BOOT-BLOCK {len(inner)} 行 >20(開機塊長胖)", "刪回 ≤20 行;修改視同修憲需使用者批准")
        blocks[name] = "\n".join(lines[b:e + 1])
    if len(blocks) == 2 and blocks["CLAUDE.md"] != blocks["AGENTS.md"]:
        rep.err("CLAUDE.md 與 AGENTS.md 的 BOOT-BLOCK 不一致", "以其中一份為準,兩處逐字同步")


# ---------- 模式 ----------

def newest_handoff(root):
    def key(p):
        m = re.match(r"^交接檔-(\d{8})-(\d{2})-", p.name)
        if m:
            return (m.group(1), m.group(2), p.name)
        m2 = re.match(r"^交接檔-(\d{8})-", p.name)
        return (m2.group(1) if m2 else "00000000", "00", p.name)

    cands = sorted(root.glob("spec-*/handoffs/交接檔-*.md"), key=key)
    return cands[-1] if cands else None


def run_latest(rep, root):
    """優先走 LATEST.md 指標;無指標才按檔名日期+流水號取最新。"""
    targets = []
    for lp in sorted(root.glob("spec-*/handoffs/LATEST.md")):
        kv, _ = parse_kv(lp.read_text(encoding="utf-8"))
        cand = root / kv.get("latest_handoff", "")
        if cand.exists():
            targets.append(cand)
        else:
            rep.err(f"{lp.relative_to(root)}:latest_handoff 指向的檔案不存在", "整檔重寫 LATEST.md 指向真實檔案")
    if not targets:
        hp = newest_handoff(root)
        if hp is None:
            rep.err("找不到任何交接檔", "先照 handoff skill 產出交接檔")
            return
        targets = [hp]
    for hp in targets:
        text = hp.read_text(encoding="utf-8")
        htype, code = handoff_type(text)
        check_name_and_place(rep, hp, root, is_new=(htype is not None))
        htype, code, secs = check_content(rep, hp, text, root)
        if htype:
            check_ctx_budget(rep, hp, text)
            check_binding(rep, hp, htype, code, secs, root, require_staged=False)
            rep.ok(f"{hp.name}(型別:{htype}{'-' + code if code else ''})內容與綁定檢查完成")
        else:
            rep.warn(f"{hp.name} 為舊格式史料;下一份新交接檔必須帶「> 型別:」聲明(新格式)")


def run_staged(rep, root):
    _, out, _ = sh(["git", "diff", "--cached", "--name-status"], cwd=root)
    staged = [(l.split("\t")[0], l.split("\t")[-1].strip('"')) for l in out.splitlines() if "\t" in l]
    touched = [(s, p) for s, p in staged
               if "/handoffs/" in p or p.endswith("pipeline-state.md")]
    if not touched:
        rep.ok("本次 commit 未觸及交接檔/state,略過")
        return
    check_frozen(rep, root)
    for status, p in touched:
        path = root / p
        if Path(p).name == "LATEST.md":
            if path.exists():
                check_latest_schema(rep, path, root)
            continue
        if Path(p).name == "pipeline-state.md":
            if path.exists():
                check_state_schema(rep, path, root)
            continue
        if not Path(p).name.startswith("交接檔-"):
            continue
        is_new = status.startswith("A")
        legacy = is_legacy_handoff(Path(p).name)
        # 史料檔案(日期<LEGACY_HANDOFF_CUTOFF)即使首次 add 亦豁免新格式強制
        enforce_new = is_new and not legacy
        check_name_and_place(rep, path, root, enforce_new)
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        htype, code, secs = check_content(rep, path, text, root)
        if htype is None and enforce_new:
            rep.err(f"{path.name}:新增交接檔必須是新格式(含「> 型別:」聲明行)", "照 handoff-template.md 補型別聲明")
        if htype:
            check_ctx_budget(rep, path, text)
            if enforce_new:  # 綁定檢查只針對「真正的」新增交接檔;史料與修改舊檔皆豁免
                check_binding(rep, path, htype, code, secs, root, require_staged=True)
    # 根目錄禁放交接檔(工作衛生)
    for status, p in staged:
        if Path(p).name.startswith("交接檔-") and "/handoffs/" not in p:
            rep.err(f"{p}:交接檔不得放在 spec-*/handoffs/ 之外", "搬到 spec-<專案代號>/handoffs/")


def run_all(rep, root):
    legacy = 0
    for hp in sorted(root.glob("spec-*/handoffs/交接檔-*.md")):
        text = hp.read_text(encoding="utf-8")
        htype, code, secs = check_content(Report(), hp, text, root)  # 舊格式偵測不污染主報告
        if htype is None:
            legacy += 1
            continue
        check_name_and_place(rep, hp, root, is_new=True)
        check_content(rep, hp, text, root)
        check_ctx_budget(rep, hp, text)
    if legacy:
        rep.ok(f"舊格式交接檔 {legacy} 份(遷移期豁免,僅驗新格式)")
    latests = sorted(root.glob("spec-*/handoffs/LATEST.md"))
    for lp in latests:
        before = len(rep.errors)
        check_latest_schema(rep, lp, root)
        if len(rep.errors) == before:
            rep.ok(f"{lp.relative_to(root)} 與其指向的 pipeline-state schema 檢查通過")
    if not latests:
        rep.warn("尚無 handoffs/LATEST.md(首份交接檔產出時由 handoff skill 建立)")
    before = len(rep.errors)
    check_boot_block(rep, root)
    if len(rep.errors) == before:
        rep.ok("BOOT-BLOCK 檢查通過(檔首、≤20 行、CLAUDE.md/AGENTS.md 一致)")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    root = repo_root()
    rep = Report()
    args = sys.argv[1:]
    mode = args[0] if args else "--latest"
    if mode == "--staged":
        run_staged(rep, root)
    elif mode == "--latest":
        run_latest(rep, root)
    elif mode == "--all":
        run_all(rep, root)
    elif mode == "--file" and len(args) > 1:
        p = Path(args[1]).resolve()
        check_name_and_place(rep, p, root, is_new=True)
        htype, code, secs = check_content(rep, p, p.read_text(encoding="utf-8"), root)
        if htype:
            rep.ok(f"{p.name} 內容檢查完成(--file 不做跨檔綁定)")
    else:
        print("用法:check_handoff.py [--staged|--latest|--all|--file <路徑>]")
        return 2
    return rep.finish()


if __name__ == "__main__":
    sys.exit(main())
