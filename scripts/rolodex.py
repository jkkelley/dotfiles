#!/usr/bin/env python3
# name: rolodex.py
# purpose: Build SYSTEM_ROLODEX.md and system-rolodex.json (what exists on this host and what does what), draft script headers, and fail a script that has none.
# inputs: config/rolodex.conf (scan roots), config/rolodex-owners.tsv (curated writer and cleanup rows), arguments override the config, see --help.
# outputs: build writes the two files; headers prints or inserts header comments; check prints offenders and exits 1.
# writes-to: build writes only SYSTEM_ROLODEX.md and system-rolodex.json; headers --write edits the scripts it names; check writes nothing.
# cleanup: nothing to clean, build writes each output directly and leaves no temp file.
#
# Owner words, 2026-10-16 UTC: "we need these documented and re-used, we should be keeping track of what does what ... propose
# something and ensure its non disruptive and not over engineered"; "Automation and scripts NEVER BY HAND".
# Design: Bearings D-22. Reuses the business repo's rolodex idea (a generated index, never hand-written) and the
# compaction-guard header convention (name, purpose, inputs, outputs, called-by), so nothing here is a new format.
#
# Usage: rolodex.py build   [--config F] [--out-md F] [--out-json F] [--no-redact]
#        rolodex.py headers [--write] [--all] [--base REF] [--root DIR] [FILE...]   (draft headers into scripts that lack one)
#        rolodex.py check   [--all] [--base REF] [--root DIR] [FILE...]   (fail a script with no header)
# Exit codes: 0 ok, 1 headerless script found, 2 usage.
import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
KEYS = ["name", "purpose", "inputs", "outputs", "writes-to", "cleanup"]
SCRIPT_EXT = {".sh", ".py", ".mjs", ".js"}
SKIP_PARTS = {".git", "node_modules", "synced", "__pycache__", ".venv"}
GOLDEN_START = "<!-- GOLDEN-RULES:START -->"
GOLDEN_END = "<!-- GOLDEN-RULES:END -->"
TOC_START = "<!-- START doctoc generated TOC please keep comment here to allow auto update -->"
TOC_NOTE = "<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->"
TOC_END = "<!-- END doctoc generated TOC please keep comment here to allow auto update -->"


def home(p):
    return Path(os.path.expanduser(p))


def tilde(p):
    s = str(p)
    h = str(Path.home())
    return "~" + s[len(h):] if s == h or s.startswith(h + "/") else s


def read_conf(path):
    """key: value lines; a repeated key makes a list. '#' starts a comment."""
    conf = {}
    for line in Path(path).read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if ":" in line:
            k, v = line.split(":", 1)
            conf.setdefault(k.strip(), []).append(v.strip())
    return conf


def head_text(path, n=60):
    try:
        with open(path, "r", errors="replace") as f:
            return [next(f, "") for _ in range(n)]
    except OSError:
        return []


def comment_lines(path, n=60):
    out = []
    for ln in head_text(path, n):
        s = ln.strip()
        if s.startswith("#!"):
            continue
        if s.startswith("#") or s.startswith("//"):
            out.append(s.lstrip("#/").strip())
        elif s == "" and not out:
            continue
        elif out:
            break
    return out


def header_of(path):
    """Header keys found in the leading comment block: name, purpose, inputs, outputs, writes-to, cleanup."""
    found = {}
    for c in comment_lines(path):
        m = re.match(r"^([a-z-]+):\s*(.*)$", c)
        if m and m.group(1) in KEYS + ["called-by"]:
            found[m.group(1)] = m.group(2)
    return found


def has_header(path):
    return all(k in header_of(path) for k in KEYS)


def is_script(path):
    p = Path(path)
    if p.suffix in SCRIPT_EXT:
        return True
    if p.suffix == "" and p.is_file() and not p.is_symlink():
        first = head_text(p, 1)
        return bool(first and first[0].startswith("#!"))
    return False


def skipped(rel):
    return bool(SKIP_PARTS & set(Path(rel).parts))


# ---------------------------------------------------------------- headers

def draft(path):
    """Draft the six header lines from what the file already says. Heuristics, marked as drafted for review."""
    p = Path(path)
    lines = p.read_text(errors="replace").splitlines()
    body = "\n".join(lines)
    cm = comment_lines(p)
    existing = header_of(p)
    purpose = existing.get("purpose")
    if not purpose:
        for c in cm:
            if c and not re.match(r"^(usage|shellcheck|set |-\*-|eslint|BREADCRUMB|Owner)", c, re.I) and len(c) > 12:
                purpose = re.sub(r"^" + re.escape(p.name) + r"\s*[-:]\s*", "", c)
                break
    purpose = purpose or "not stated in the file - drafted, fill in"
    flags = sorted(set(re.findall(r"(?<![\w-])(--[a-z][a-z0-9-]+)", body)))[:6]
    envs = sorted(set(re.findall(r"\$\{([A-Z][A-Z0-9_]{2,}):[-?=]", body)))[:5]
    usage = next((c for c in cm if c.lower().startswith("usage")), "")
    inputs = usage[6:].strip(": ") if usage else ""
    if not inputs:
        parts = ([" ".join(flags)] if flags else []) + (["env " + " ".join(envs)] if envs else [])
        inputs = "; ".join(parts) or ("arguments" if re.search(r"\$\{?1\b|sys\.argv|argparse|process\.argv", body) else "none")
    outs = []
    if re.search(r"^\s*(echo|printf)\b|\bprint\(|console\.log", body, re.M):
        outs.append("stdout")
    if re.search(r"\bexit\b|sys\.exit|process\.exit", body):
        outs.append("exit code")
    outputs = ", ".join(outs) or "none"
    writes = []
    writes += sorted(set(re.findall(r"((?:~|\$HOME)/\.(?:local/state|config|cache)/[\w./${}-]+)", body)))[:3]
    writes += sorted(set(re.findall(r"(?:>>?|tee(?: -a)?)\s+\"?([\w./${}~-]+\.(?:log|json|md|tsv|txt|jsonl))", body)))[:3]
    if "mktemp" in body:
        writes.append("a mktemp scratch path")
    if re.search(r"\bgit (commit|push)\b|\bgh pr (create|merge)", body):
        writes.append("git branches and PRs")
    writes = [w.rstrip("$/{.-") for w in writes]
    writes_to = ", ".join(dict.fromkeys(w for w in writes if w)) or "nothing (read-only)"
    if re.search(r"\btrap\b[^\n]*(EXIT|INT)|\brm (-\w+ )?", body):
        cleanup = "removes its own temp files on exit"
    elif writes_to.startswith("nothing"):
        cleanup = "none needed"
    else:
        cleanup = "none in the file - drafted, confirm what removes its output"
    return {"name": p.name, "purpose": purpose, "inputs": inputs, "outputs": outputs, "writes-to": writes_to, "cleanup": cleanup}


def insert_header(path):
    p = Path(path)
    text = p.read_text(errors="replace")
    lines = text.splitlines(keepends=True)
    d = draft(p)
    have = header_of(p)
    block = ["# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong\n"]
    block += [f"# {k}: {d[k]}\n" for k in KEYS if k not in have]
    at = 1 if lines and lines[0].startswith("#!") else 0
    lines[at:at] = block
    p.write_text("".join(lines))


# ---------------------------------------------------------------- script discovery

def git(root, *args):
    r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    return r.stdout.splitlines() if r.returncode == 0 else None


def tracked_scripts(root):
    files = git(root, "ls-files")
    if files is None:
        files = [str(x.relative_to(root)) for x in Path(root).rglob("*") if x.is_file()]
    return [f for f in files if not skipped(f) and is_script(Path(root) / f)]


def changed_scripts(root, base):
    files = git(root, "diff", "--name-only", "--diff-filter=A", f"{base}...HEAD") or []
    files += git(root, "ls-files", "--others", "--exclude-standard") or []
    return [f for f in files if not skipped(f) and (root / f).is_file() and is_script(root / f)]


def load_conf(args_config=None):
    return read_conf(args_config or REPO / "config" / "rolodex.conf")


# Breadcrumb, WO-20261016-88d3. What broke: headers with no FILE drafted every script under the header_root dirs of
# config/rolodex.conf, while check flags the diff set (added vs base, plus untracked), so the hint check prints
# ("make rolodex-headers WRITE=1") rewrote old scripts the PR never touched and missed a flagged script outside those dirs.
# Why this fix: one function, changed_scripts, feeds both commands, and both read the same --base default (env BASE, which
# GNU make exports from a command-line BASE=x), so they cannot drift. Rejected: keeping header_root as the default, it is the bug.
# Cost: the header_root lines in config/rolodex.conf are now unread; their removal is held by WO-20261016-6cff.
def cmd_headers(a):
    root = Path(a.root).resolve()
    files = a.files or (tracked_scripts(root) if a.all else changed_scripts(root, a.base))
    todo = [f for f in files if not has_header(root / f)]
    for f in todo:
        if a.write:
            insert_header(root / f)
            print(f"headers: wrote {f}")
        else:
            d = draft(root / f)
            print(f"--- {f}")
            for k in KEYS:
                print(f"# {k}: {d[k]}")
    print(f"headers: {len(todo)} of {len(files)} scripts lacked a header" + ("" if a.write else " (dry run, --write inserts)"))
    return 0


def cmd_check(a):
    root = Path(a.root).resolve()
    if a.files:
        files = a.files
    elif a.all:
        files = tracked_scripts(root)
    else:
        files = changed_scripts(root, a.base)
    bad = [f for f in files if not has_header(root / f)]
    for f in bad:
        missing = [k for k in KEYS if k not in header_of(root / f)]
        print(f"rolodex-check: {f} lacks header keys: {', '.join(missing)}", file=sys.stderr)
    if bad:
        print("rolodex-check: fix with: make rolodex-headers WRITE=1 (drafts them), then correct any wrong line", file=sys.stderr)
        return 1
    print(f"rolodex-check: {len(files)} script(s) checked, all have headers")
    return 0


# ---------------------------------------------------------------- scan

def md_title(path):
    for ln in head_text(path, 40):
        if ln.startswith("# "):
            return ln[2:].strip()
    return ""


def readme_line(d):
    for name in ("README.md", "CLAUDE.md", "AGENTS.md"):
        p = d / name
        if p.is_file():
            for ln in head_text(p, 60):
                s = ln.strip()
                if s and not s.startswith(("#", "<!--", "-", "|", "[", "```", ">", "*")) and len(s) > 20:
                    return s[:140]
            t = md_title(p)
            if t:
                return t[:140]
    return ""


def worktree_parent(d):
    g = d / ".git"
    if g.is_file():
        m = re.match(r"gitdir:\s*(.+)", g.read_text().strip())
        if m:
            gd = Path(m.group(1))
            if "worktrees" in gd.parts:
                return gd.parent.parent.parent
    return None


def scan_repos(conf):
    repos = []
    for r in conf.get("repo_root", []):
        base = home(r)
        if not base.is_dir():
            continue
        cands = [base] if (base / ".git").exists() else sorted(x for x in base.iterdir() if x.is_dir() and not x.name.startswith("."))
        for d in cands:
            if not (d / ".git").exists():
                continue
            wp = worktree_parent(d)
            repos.append({
                "name": d.name, "path": tilde(d),
                "kind": "worktree" if wp else "repo",
                "worktree_of": tilde(wp) if wp else None,
                "what": readme_line(d),
                "rolodex": tilde(d / "ROLODEX.md") if (d / "ROLODEX.md").is_file() else None,
                "agent_files": [n for n in ("AGENTS.md", "CLAUDE.md", "GEMINI.md") if (d / n).is_file()],
            })
    return repos


def scan_scripts(conf, repos):
    """Scripts in header roots of every real repo plus bin dirs: the source of 'who writes' and 'cleanup' for state folders."""
    out = []
    for r in repos:
        if r["kind"] != "repo":
            continue
        d = home(r["path"])
        for sub in ("scripts", "tools", "bin", "claude/tools"):
            sd = d / sub
            if not sd.is_dir():
                continue
            for dp, dn, fn in os.walk(sd):
                dn[:] = [x for x in dn if x not in SKIP_PARTS and dp.count("/") - str(sd).count("/") < 3]
                for f in fn:
                    fp = Path(dp) / f
                    if is_script(fp):
                        h = header_of(fp)
                        if h.get("writes-to"):
                            out.append((f"{r['name']}:{fp.relative_to(d)}", h))
    return out


def scan_bin(conf):
    out = []
    for b in conf.get("bin_dir", []):
        bd = home(b)
        if not bd.is_dir():
            continue
        for f in sorted(bd.iterdir()):
            target = tilde(os.path.realpath(f)) if f.is_symlink() else None
            purpose, kind = "", "binary"
            real = Path(os.path.realpath(f))
            if real.is_file() and real.stat().st_size < 400_000:
                first = head_text(real, 1)
                if first and first[0].startswith("#!"):
                    kind = "script"
                    h = header_of(real)
                    purpose = h.get("purpose") or next((c for c in comment_lines(real) if len(c) > 12), "")
            elif real.is_dir():
                kind = "dir"
            out.append({"name": f.name, "kind": kind, "link": target, "purpose": purpose[:160], "headered": kind == "script" and has_header(real)})
    return out


def read_owners(path):
    rows = {}
    if Path(path).is_file():
        for ln in Path(path).read_text().splitlines():
            if ln.strip() and not ln.startswith("#"):
                c = ln.split("\t")
                if len(c) >= 3:
                    rows[c[0].strip()] = (c[1].strip(), c[2].strip())
    return rows


def writers_for(token, script_headers):
    w, c = [], []
    for name, h in script_headers:
        if token in h.get("writes-to", ""):
            w.append(name)
            if h.get("cleanup"):
                c.append(h["cleanup"])
    return w, c


def scan_state(conf, script_headers, owners):
    out = []
    for s in conf.get("state_root", []):
        sd = home(s)
        if not sd.is_dir():
            continue
        for d in sorted(x for x in sd.iterdir() if x.is_dir()):
            key = tilde(d)
            if key in owners:
                writer, cleanup = owners[key]
                src = "owners.tsv"
            else:
                w, c = writers_for(d.name, script_headers)
                writer = ", ".join(w[:3]) or "unknown"
                cleanup = c[0] if c else "unknown"
                src = "script headers" if w else "none"
            out.append({"path": key, "writer": writer, "cleanup": cleanup, "source": src})
        for f in sorted(x for x in sd.iterdir() if x.is_file()):
            key = tilde(f)
            if key in owners:
                out.append({"path": key, "writer": owners[key][0], "cleanup": owners[key][1], "source": "owners.tsv"})
    return out


def scan_globals(conf):
    out, seen = [], set()
    for lst in conf.get("global_list", []):
        p = REPO / lst
        if not p.is_file():
            continue
        for ln in p.read_text().splitlines():
            ln = ln.strip()
            if not ln or ln.startswith("#"):
                continue
            f = home(ln)
            if f.is_file():
                real = os.path.realpath(f)
                if real not in seen:
                    seen.add(real)
                    out.append({"path": tilde(real), "what": md_title(real)})
    for ln in conf.get("global_extra", []):
        f = home(ln)
        if f.is_file() and os.path.realpath(f) not in seen:
            seen.add(os.path.realpath(f))
            out.append({"path": tilde(os.path.realpath(f)), "what": md_title(f)})
    return sorted(out, key=lambda x: x["path"])


def scan_windows(conf, owners):
    out = []
    for r in conf.get("win_root", []):
        root = Path(r)
        if not root.is_dir():
            continue
        for pat in conf.get("win_dir", []):
            for d in sorted(root.glob(pat)):
                if d.is_dir():
                    key = str(d)
                    writer, cleanup = owners.get(key, ("unknown", "unknown"))
                    out.append({"path": key, "writer": writer, "cleanup": cleanup})
    return out


# ---------------------------------------------------------------- render

def slug(h, seen):
    s = re.sub(r"[^\w\- ]", "", h.lower()).replace(" ", "-")
    n = seen.get(s, 0)
    seen[s] = n + 1
    return s if n == 0 else f"{s}-{n}"


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "| " + " | ".join("-" * len(h) for h in head) + " |"]
    for r in rows:
        out.append("| " + " | ".join(str(c if c not in (None, "") else "-").replace("|", "/") for c in r) + " |")
    return out


def cell(s):
    return f"`{s}`" if s and s not in ("unknown", "-") else (s or "-")


def render(data, golden):
    secs = []
    rr = [r for r in data["repos"] if r["kind"] == "repo"]
    wt = [r for r in data["repos"] if r["kind"] == "worktree"]
    s = ["## Repositories", "",
         f"{len(rr)} repositories, plus {len(wt)} worktrees listed under the repo they belong to. `ROLODEX` means the repo has its own generated index to read next.", ""]
    s += table(["Repo", "What it is", "Own ROLODEX", "Agent files", "Worktrees"],
               [(cell(r["path"]), r["what"], "yes" if r["rolodex"] else "-", ", ".join(r["agent_files"]),
                 ", ".join(w["name"] for w in wt if w["worktree_of"] == r["path"])) for r in rr])
    orphans = [w for w in wt if w["worktree_of"] not in {r["path"] for r in rr}]
    if orphans:
        s += ["", "Worktrees whose repo is outside the scan roots: " + ", ".join(f"`{w['path']}` (of `{w['worktree_of']}`)" for w in orphans)]
    secs.append(s)
    secs.append(["## Tools on PATH", "", "Everything in the bin directories. `headered` means the script carries the six header keys.", ""]
                + table(["Tool", "Kind", "Links to", "Purpose", "Headered"],
                        [(cell(t["name"]), t["kind"], cell(t["link"]), t["purpose"], "yes" if t["headered"] else "-") for t in data["tools"]]))
    secs.append(["## State folders", "",
                 "Who writes each folder and what cleans it. `unknown` is a gap: add a row to `config/rolodex-owners.tsv` or give the writing script a `writes-to:` and `cleanup:` header.", ""]
                + table(["Path", "Written by", "Cleanup"], [(cell(x["path"]), x["writer"], x["cleanup"]) for x in data["state"]]))
    secs.append(["## Global files outside any repo", "", "Agent instruction files and notes the owner keeps outside git.", ""]
                + table(["File", "Title"], [(cell(x["path"]), x["what"]) for x in data["globals"]]))
    secs.append(["## Windows folders", "", "Folders under the Windows profile used by the browser seats.", ""]
                + table(["Folder", "Written by", "Cleanup"], [(cell(x["path"]), x["writer"], x["cleanup"]) for x in data["windows"]]))
    secs.append(["## How this file is made", "",
                 "Generated by `scripts/rolodex.py build` (`make rolodex`) from `config/rolodex.conf`. Do not hand-edit: a hand-edit is lost on the next build.",
                 "`make rolodex-headers` drafts the missing script headers, and `make rolodex-check` fails a new script that has none.",
                 "The scan is read-only and writes only `SYSTEM_ROLODEX.md` and `system-rolodex.json`."])
    body_heads = [ln[3:] for sec in secs for ln in sec if ln.startswith("## ")]
    gold_heads = [ln[3:] for ln in golden.splitlines() if ln.startswith("## ")]
    seen = {}
    toc = [f"- [{h}](#{slug(h, seen)})" for h in gold_heads + body_heads]
    out = ["# System Rolodex", "", TOC_START, TOC_NOTE, "", *toc, "", TOC_END, "",
           GOLDEN_START, *golden.rstrip("\n").splitlines(), GOLDEN_END, "",
           "What exists on this host and what does what: repos, tools, state folders, global files and Windows folders.", ""]
    for sec in secs:
        out += sec + [""]
    return "\n".join(out).rstrip("\n") + "\n"


def redact(obj, pats):
    """The committed output lands in a public repo (CLAUDE.md PII policy), so private names become <private>."""
    if isinstance(obj, str):
        for p in pats:
            obj = re.sub(p, "<private>", obj, flags=re.I)
        return obj
    if isinstance(obj, list):
        return [redact(x, pats) for x in obj]
    if isinstance(obj, dict):
        return {k: redact(v, pats) for k, v in obj.items()}
    return obj


def cmd_build(a):
    conf = load_conf(a.config)
    owners = read_owners(REPO / conf.get("owners", ["config/rolodex-owners.tsv"])[0])
    repos = scan_repos(conf)
    headers = scan_scripts(conf, repos)
    data = {
        "schema": "system-rolodex/1",
        "repos": repos,
        "tools": scan_bin(conf),
        "state": scan_state(conf, headers, owners),
        "globals": scan_globals(conf),
        "windows": scan_windows(conf, owners),
    }
    if not a.no_redact:
        data = redact(data, conf.get("redact", []))
    golden = (REPO / "claude" / "golden-rules.md").read_text()
    Path(a.out_json).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    Path(a.out_md).write_text(render(data, golden))
    print(f"rolodex: {len(repos)} repos, {len(data['tools'])} tools, {len(data['state'])} state entries, "
          f"{len(data['globals'])} global files, {len(data['windows'])} windows folders -> {a.out_md}, {a.out_json}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__ or "rolodex")
    ap.add_argument("--config")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--config", dest="config")
    b.add_argument("--out-md", default=str(REPO / "SYSTEM_ROLODEX.md"))
    b.add_argument("--out-json", default=str(REPO / "system-rolodex.json"))
    b.add_argument("--no-redact", action="store_true", help="keep private names; for output that stays out of git")
    h = sub.add_parser("headers")
    h.add_argument("--config", dest="config")
    h.add_argument("--write", action="store_true")
    h.add_argument("--all", action="store_true")
    h.add_argument("--base", default=os.environ.get("BASE") or "origin/main")
    h.add_argument("--root", default=str(REPO))
    h.add_argument("files", nargs="*")
    c = sub.add_parser("check")
    c.add_argument("--config", dest="config")
    c.add_argument("--all", action="store_true")
    c.add_argument("--base", default=os.environ.get("BASE") or "origin/main")
    c.add_argument("--root", default=str(REPO))
    c.add_argument("files", nargs="*")
    a = ap.parse_args()
    return {"build": cmd_build, "headers": cmd_headers, "check": cmd_check}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
