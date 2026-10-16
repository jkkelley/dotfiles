#!/usr/bin/env python3
# name: wiki_index.py
# purpose: Generate <WIKI>/index/README.md from processed pages: contents, pages table, topic map and backlinks per raw file.
# inputs: argv ROOT; <ROOT>/wiki.json via wikilib; <ROOT>/<processed_dir>/*.md frontmatter (id, title, topic, sources) and section anchors.
# outputs: "WIKI-020 <index path>" on stdout; exit 0 ok, 2 usage, 4 io (missing processed dir, unreadable page, bad config).
# writes-to: <ROOT>/<index_dir>/README.md, atomic, deterministic bytes; a rerun leaves the file unchanged.
# cleanup: none needed; delete the index by removing its file.
#
# Design: docs/design/wiki.spec.xml (verb index, code WIKI-020).
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wikilib  # noqa: E402

SECTION = re.compile(r'^## <a id="[^"]+"></a>')


def load_pages(proc_dir):
    pages = []
    for p in sorted(proc_dir.glob("*.md")):
        meta, body = wikilib.read_frontmatter(p.read_text())
        pid = meta.get("id") or p.stem
        sources = [s.strip() for s in meta.get("sources", "").split(",") if s.strip()]
        sections = sum(1 for ln in body.split("\n") if SECTION.match(ln))
        pages.append({"id": pid, "file": p.name, "title": meta.get("title", pid),
                      "topic": meta.get("topic", "") or "untopiced", "sources": sources, "sections": sections})
    pages.sort(key=lambda x: x["id"])
    return pages


def render(pages, to_proc, to_raw):
    out = ["# Index", "", "## Contents", "", "- [Pages](#pages)", "- [Topic map](#topic-map)", "- [Backlinks](#backlinks)", ""]
    out += ["## Pages", "", "| Page | Title | Sections |", "| --- | --- | --- |"]
    for pg in pages:
        out.append("| [%s](%s/%s) | %s | %d |" % (pg["id"], to_proc, pg["file"], pg["title"], pg["sections"]))
    out += ["", "## Topic map"]
    for topic in sorted({pg["topic"] for pg in pages}):
        out += ["", "### %s" % topic, ""]
        out += ["- [%s](%s/%s) - %s" % (pg["id"], to_proc, pg["file"], pg["title"]) for pg in pages if pg["topic"] == topic]
    out += ["", "## Backlinks"]
    cites = {}
    for pg in pages:
        for s in pg["sources"]:
            cites.setdefault(s, []).append(pg)
    for raw in sorted(cites):
        out += ["", "### [%s](%s/%s)" % (raw, to_raw, raw), ""]
        out += ["- [%s](%s/%s)" % (pg["id"], to_proc, pg["file"]) for pg in cites[raw]]
    return "\n".join(out) + "\n"


def main(argv):
    if len(argv) != 2 or not argv[1]:
        print("usage: wiki_index.py ROOT", file=sys.stderr)
        return 2
    root = Path(argv[1])
    try:
        cfg = wikilib.load_config(root)
        proc_dir = root / cfg["processed_dir"]
        if not proc_dir.is_dir():
            print("%s: no such directory" % proc_dir, file=sys.stderr)
            return 4
        index_dir = root / cfg["index_dir"]
        rel = lambda d: os.path.relpath(root / d, index_dir)  # noqa: E731
        text = render(load_pages(proc_dir), rel(cfg["processed_dir"]), rel(cfg["raw_dir"]))
        target = index_dir / "README.md"
        if not (target.exists() and target.read_text() == text):
            wikilib.atomic_write(target, text)
    except (OSError, ValueError) as e:
        print("io: %s" % e, file=sys.stderr)
        return 4
    print("WIKI-020 %s" % target)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
