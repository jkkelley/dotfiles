#!/usr/bin/env python3
# name: wikilib.py
# purpose: Shared stdlib helpers for the wiki engine verbs: time, hashing, slugs, frontmatter, config, atomic writes, secret patterns.
# inputs: <WIKI>/wiki.json and <WIKI>/secret-patterns.json when present; defaults from secret-patterns.json beside this file.
# outputs: return values only; atomic_write writes the one file it is given.
# writes-to: atomic_write writes its target path and a temp file beside it, which it renames away.
# cleanup: atomic_write removes its temp file on failure; nothing else is left behind.
#
# Design: docs/design/wiki.spec.xml (layout). Called by wiki_<verb>.py; never run directly.
import hashlib
import json
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULTS = {
    "intake_dir": "intake",
    "raw_dir": "raw",
    "processed_dir": "processed",
    "index_dir": "index",
    "blob_limit_bytes": 1048576,
    "max_page_lines": 200,
    "review_dir": None,
    "artifact_new": "make -s -C ~/dotfiles artifact-new",
}


def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def slug(text, limit=48):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:limit].strip("-") or "untitled"


def read_frontmatter(text):
    """Return (dict, body). Frontmatter is flat `key: value` lines between two --- lines; none gives ({}, text)."""
    lines = text.split("\n")
    if not lines or lines[0] != "---":
        return {}, text
    for i in range(1, len(lines)):
        if lines[i] == "---":
            meta = {}
            for ln in lines[1:i]:
                if ":" in ln:
                    k, v = ln.split(":", 1)
                    meta[k.strip()] = v.strip()
            return meta, "\n".join(lines[i + 1:])
    return {}, text


def write_frontmatter(meta, body):
    head = "".join("%s: %s\n" % (k, v) for k, v in meta.items())
    return "---\n" + head + "---\n" + body


def load_config(root):
    """Defaults overlaid by <root>/wiki.json; a missing file is the defaults, a malformed one raises ValueError."""
    cfg = dict(DEFAULTS)
    p = Path(root) / "wiki.json"
    if p.exists():
        try:
            cfg.update(json.loads(p.read_text()))
        except json.JSONDecodeError as e:
            raise ValueError("%s: %s" % (p, e))
    return cfg


def atomic_write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".wiki-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data if isinstance(data, bytes) else data.encode("utf-8"))
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def secret_patterns(root=None):
    """Compiled patterns: <root>/secret-patterns.json overrides the default file beside this module."""
    p = Path(root) / "secret-patterns.json" if root else None
    if p is None or not p.exists():
        p = HERE / "secret-patterns.json"
    return [re.compile(x) for x in json.loads(p.read_text())["patterns"]]
