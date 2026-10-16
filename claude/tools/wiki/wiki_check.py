#!/usr/bin/env python3
# name: wiki_check.py
# purpose: Read-only wiki check: fails a page with no contents list, a broken relative link, an uncited section, a size breach, a secret or TODO-WRITE, and a raw capture no page cites.
# inputs: ROOT (a wiki root with wiki.json); processed/*.md, index/README.md, raw/*.md; secret patterns via wikilib.
# outputs: one 'CODE path:line' per finding on stdout, WIKI-030 summary last; WIKI-000 when clean. Exit 0 ok, 2 usage, 3 findings, 4 io.
# writes-to: nothing; stdout only.
# cleanup: none needed.
#
# Design: docs/design/wiki.spec.xml (verbs, check; codes WIKI-030 to WIKI-037).
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wikilib  # noqa: E402

LINK = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)\)")
ANCHOR = re.compile(r'<a id="([^"]+)"></a>')
H2 = re.compile(r"^## (.*)$")


def heading_slug(text):
    text = re.sub(r"<[^>]+>", "", text).strip().lower()
    return re.sub(r"\s", "-", re.sub(r"[^\w\s-]", "", text))


def anchors_of(path, cache):
    if path not in cache:
        found = set()
        for ln in path.read_text(errors="replace").split("\n"):
            found.update(ANCHOR.findall(ln))
            m = re.match(r"^#{1,6} (.*)$", ln)
            if m:
                found.add(heading_slug(m.group(1)))
        cache[path] = found
    return cache[path]


def iter_lines(text):
    """Yield (lineno, line, in_fence); links and headings are read outside fences only."""
    fence = False
    for n, ln in enumerate(text.split("\n"), 1):
        if ln.lstrip().startswith("```"):
            fence = not fence
            yield n, ln, True
            continue
        yield n, ln, fence


def check_page(root, page, cfg, cache, findings):
    rel = page.relative_to(root)
    text = page.read_text(errors="replace")
    lines = text.split("\n")
    if len(lines) > int(cfg["max_page_lines"]):
        findings.append(("WIKI-035", rel, len(lines)))
    sections = []  # [heading line, has_raw_link]
    first_h2 = None
    is_processed = page.parent == root / cfg["processed_dir"]
    for n, ln, fence in iter_lines(text):
        if "TODO-WRITE" in ln and is_processed:
            findings.append(("WIKI-037", rel, n))
        if fence:
            continue
        m = H2.match(ln)
        if m:
            if first_h2 is None:
                first_h2 = (n, m.group(1).strip())
            elif is_processed:
                sections.append([n, False])
            continue
        for target in LINK.findall(ln):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("//"):
                continue
            path_part, _, frag = target.partition("#")
            dest = (page.parent / path_part).resolve() if path_part else page
            if path_part and not dest.is_file():
                findings.append(("WIKI-032", rel, n))
                continue
            if frag and dest.suffix == ".md" and frag not in anchors_of(dest, cache):
                findings.append(("WIKI-032", rel, n))
                continue
            if path_part and dest.parent == (root / cfg["raw_dir"]).resolve() and dest.suffix == ".md":
                if sections:
                    sections[-1][1] = True
    if first_h2 is None or first_h2[1] != "Contents":
        findings.append(("WIKI-031", rel, first_h2[0] if first_h2 else 1))
    for n, ok in sections:
        if not ok:
            findings.append(("WIKI-034", rel, n))


def main(argv):
    if len(argv) != 2 or not argv[1]:
        print("usage: wiki_check.py ROOT", file=sys.stderr)
        return 2
    root = Path(argv[1]).resolve()
    if not root.is_dir():
        print("WIKI: not a directory: %s" % argv[1], file=sys.stderr)
        return 2
    try:
        cfg = wikilib.load_config(root)
        pats = wikilib.secret_patterns(root)
    except (ValueError, OSError, KeyError) as e:
        print("WIKI io: %s" % e, file=sys.stderr)
        return 4
    findings, cache = [], {}
    pages = sorted((root / cfg["processed_dir"]).glob("*.md"))
    index = root / cfg["index_dir"] / "README.md"
    if index.is_file():
        pages.append(index)
    raws = sorted((root / cfg["raw_dir"]).glob("*.md"))
    try:
        for p in pages:
            check_page(root, p, cfg, cache, findings)
        for p in raws + [q for q in pages if q != index]:
            for n, ln in enumerate(p.read_text(errors="replace").split("\n"), 1):
                if any(pat.search(ln) for pat in pats):
                    findings.append(("WIKI-036", p.relative_to(root), n))
    except OSError as e:
        print("WIKI io: %s" % e, file=sys.stderr)
        return 4
    # Orphan: cited only by processed pages; the index lists every raw file in Backlinks and must not hide an orphan.
    cited_by_pages = set()
    for p in pages:
        if p != index:
            cited_by_pages.update(Path(t.partition("#")[0]).name for t in LINK.findall(p.read_text(errors="replace")) if "../raw/" in t)
    for r in raws:
        if r.name not in cited_by_pages:
            findings.append(("WIKI-033", r.relative_to(root), 1))
    if not findings:
        print("WIKI-000 ok")
        return 0
    for code, rel, n in sorted(findings, key=lambda f: (str(f[1]), f[2], f[0])):
        print("%s %s:%d" % (code, rel, n))
    print("WIKI-030 check failed: %d findings" % len(findings))
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
