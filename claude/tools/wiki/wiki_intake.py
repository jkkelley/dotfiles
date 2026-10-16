#!/usr/bin/env python3
# name: wiki_intake.py
# purpose: Capture source files into <WIKI>/raw by content hash; a second run adds nothing, big blobs go to the artifact store.
# inputs: argv ROOT SRC...; SRC is a file or a directory (recurses over *.md, *.xml, *.json, sorted); <ROOT>/wiki.json via wikilib.
# outputs: one line per source on stdout: "WIKI-001|WIKI-002|WIKI-003 <raw path>"; exit 0 ok, 2 usage, 4 io.
# writes-to: <ROOT>/<raw_dir>/<sha12>-<slug>.md; sources over blob_limit_bytes also write the path printed by artifact_new.
# cleanup: writes are atomic; nothing is left behind. Delete a capture by removing its raw file.
#
# Design: docs/design/wiki.spec.xml (verb intake). Fallback: artifact_new fails -> artifact.sh new, same KEY NAME EXT (FB-004).
import os
import shlex
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wikilib  # noqa: E402

SUFFIXES = (".md", ".xml", ".json")
ARTIFACT_SH = Path(__file__).resolve().parent.parent / "artifact" / "artifact.sh"


def expand(srcs):
    out = []
    for s in srcs:
        p = Path(s)
        if p.is_dir():
            out.extend(sorted(f for f in p.rglob("*") if f.is_file() and f.suffix in SUFFIXES))
        elif p.is_file():
            out.append(p)
        else:
            raise OSError("no such source: %s" % s)
    return out


def tilde(path):
    home = str(Path.home())
    s = str(path)
    return "~" + s[len(home):] if s == home or s.startswith(home + os.sep) else s


def store_path(cfg, name):
    """Print path from artifact_new; when it fails, the artifact.sh path with the same KEY NAME EXT (FB-004)."""
    cmd = shlex.split(os.path.expanduser(cfg["artifact_new"])) + ["KEY=context", "NAME=" + name, "EXT=bin"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        sys.stderr.write("FB-004 artifact_new failed, using artifact.sh\n")
        r = subprocess.run(["bash", str(ARTIFACT_SH), "new", "--key", "context", "--name", name, "--ext", "bin"],
                           capture_output=True, text=True)
        if r.returncode != 0 or not r.stdout.strip():
            raise OSError("artifact store unavailable: %s" % r.stderr.strip())
    return r.stdout.strip().splitlines()[-1]


def capture(root, cfg, src):
    data = src.read_bytes()
    digest = wikilib.sha256_file(src)
    sha12 = digest[:12]
    raw_dir = Path(root) / cfg["raw_dir"]
    existing = sorted(raw_dir.glob(sha12 + "-*.md")) if raw_dir.is_dir() else []
    if existing:
        return "WIKI-002", existing[0]
    target = raw_dir / ("%s-%s.md" % (sha12, wikilib.slug(src.name)))
    meta = {"source": tilde(src.resolve()), "captured_at": wikilib.utc_now(), "sha256": digest, "bytes": len(data)}
    code = "WIKI-001"
    if len(data) > cfg["blob_limit_bytes"]:
        blob = store_path(cfg, wikilib.slug(src.name, 38))
        wikilib.atomic_write(blob, data)
        meta["blob"] = tilde(blob)
        body = ""
        code = "WIKI-003"
    else:
        body = data.decode("utf-8", errors="replace")
    wikilib.atomic_write(target, wikilib.write_frontmatter(meta, body))
    return code, target


def main(argv):
    if len(argv) < 3:
        sys.stderr.write("usage: wiki_intake.py ROOT SRC...\n")
        return 2
    root, srcs = argv[1], argv[2:]
    try:
        cfg = wikilib.load_config(root)
        files = expand(srcs)
        for f in files:
            code, path = capture(root, cfg, f)
            print("%s %s" % (code, path))
    except (OSError, ValueError) as e:
        sys.stderr.write("wiki_intake: %s\n" % e)
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
