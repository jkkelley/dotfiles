#!/usr/bin/env python3
# name: wiki_process.py
# purpose: Write processed page skeletons from <WIKI>/pages.json with raw citations; rewrite only sources and updated of a present page, append missing sections, never touch written prose.
# inputs: argv ROOT; <ROOT>/pages.json (list of {id,title,topic,sources,sections:[{anchor,heading}]}) and <ROOT>/wiki.json via wikilib; raw captures by file name.
# outputs: one line per page on stdout: "WIKI-010|WIKI-011 <page path>" (WIKI-034 <page> <raw file> per missing source); exit 0 ok, 2 usage, 3 source missing from raw, 4 io.
# writes-to: <ROOT>/<processed_dir>/<id>.md, atomic; nothing is written when any source is missing.
# cleanup: none needed; a rerun is byte identical. Delete a page by removing its file.
#
# Design: docs/design/wiki.spec.xml (verb process). Spec Gaps: WIKI-034 here means a page source missing from raw (design, Gaps).
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wikilib  # noqa: E402

TODO = "TODO-WRITE"
SECTION = re.compile(r'^## <a id="([^"]+)"></a>')
ID_OK = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def load_pages(root):
    p = Path(root) / "pages.json"
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError("%s: %s" % (p, e))
    pages = data.get("pages") if isinstance(data, dict) else data
    if not isinstance(pages, list):
        raise ValueError("%s: expected a list of pages" % p)
    for pg in pages:
        for k in ("id", "title", "topic", "sources", "sections"):
            if k not in pg:
                raise ValueError("%s: page missing key %s" % (p, k))
        if not ID_OK.match(str(pg["id"])):
            raise ValueError("%s: bad page id %r" % (p, pg["id"]))
        for s in pg["sections"]:
            if "anchor" not in s or "heading" not in s:
                raise ValueError("%s: page %s section needs anchor and heading" % (p, pg["id"]))
    return pages


def cites(sources):
    return "\n".join("[raw: %s](../raw/%s)" % (s, s) for s in sources)


def section_text(sec, sources):
    return '## <a id="%s"></a>%s\n\n%s\n\n%s\n' % (sec["anchor"], sec["heading"], TODO, cites(sources))


def skeleton(pg, today):
    meta = {"id": pg["id"], "title": pg["title"], "topic": pg["topic"],
            "sources": ", ".join(pg["sources"]), "updated": today}
    contents = "\n".join("- [%s](#%s)" % (s["heading"], s["anchor"]) for s in pg["sections"])
    body = "# %s\n\n## Contents\n\n%s\n" % (pg["title"], contents)
    for s in pg["sections"]:
        body += "\n" + section_text(s, pg["sources"])
    return wikilib.write_frontmatter(meta, body)


def update(text, pg, today):
    """Return the new text of a present page: sources, updated, missing contents entries and sections only."""
    lines = text.split("\n")
    end = lines.index("---", 1) if lines and lines[0] == "---" and "---" in lines[1:] else None
    if end is None:
        raise ValueError("page %s has no frontmatter" % pg["id"])
    have = {m.group(1) for m in (SECTION.match(ln) for ln in lines) if m}
    missing = [s for s in pg["sections"] if s["anchor"] not in have]
    want = ", ".join(pg["sources"])
    cur = next((ln.split(":", 1)[1].strip() for ln in lines[1:end] if ln.startswith("sources:")), None)
    if cur == want and not missing:
        return text
    head = []
    for ln in lines[1:end]:
        if ln.startswith("sources:"):
            ln = "sources: " + want
        elif ln.startswith("updated:"):
            ln = "updated: " + today
        head.append(ln)
    if not any(ln.startswith("sources:") for ln in head):
        head.append("sources: " + want)
    if not any(ln.startswith("updated:") for ln in head):
        head.append("updated: " + today)
    body = lines[end + 1:]
    if missing:
        entries = ["- [%s](#%s)" % (s["heading"], s["anchor"]) for s in missing]
        at = next((i for i, ln in enumerate(body) if ln == "## Contents"), None)
        if at is not None:
            stop = next((i for i in range(at + 1, len(body)) if body[i].startswith("## ")), len(body))
            while stop > at + 1 and body[stop - 1] == "":
                stop -= 1
            body[stop:stop] = entries
        while body and body[-1] == "":
            body.pop()
        for s in missing:
            body += [""] + section_text(s, pg["sources"]).rstrip("\n").split("\n")
        body.append("")
    return "---\n" + "\n".join(head) + "\n---\n" + "\n".join(body)


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: wiki_process.py ROOT\n")
        return 2
    root = argv[1]
    try:
        cfg = wikilib.load_config(root)
        pages = load_pages(root)
        raw = Path(root) / cfg["raw_dir"]
        gone = [(pg["id"], s) for pg in pages for s in pg["sources"] if not (raw / s).is_file()]
        if gone:
            for pid, s in gone:
                print("WIKI-034 %s %s" % (pid, s))
            return 3
        today = wikilib.utc_now()[:10]
        out = Path(root) / cfg["processed_dir"]
        for pg in pages:
            path = out / (pg["id"] + ".md")
            old = path.read_text() if path.exists() else None
            new = skeleton(pg, today) if old is None else update(old, pg, today)
            if new == old:
                print("WIKI-011 %s" % path)
            else:
                wikilib.atomic_write(path, new)
                print("WIKI-010 %s" % path)
    except (OSError, ValueError) as e:
        sys.stderr.write("wiki_process: %s\n" % e)
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
