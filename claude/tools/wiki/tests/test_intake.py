#!/usr/bin/env python3
# name: test_intake.py
# purpose: Unit tests for wiki_intake.py: capture by content hash, idempotency, blob routing and the artifact fallback.
# inputs: none; builds a temp wiki root, sources and a fake artifact_new per test.
# outputs: unittest result on stdout; the last line is OK on success.
# writes-to: a temp directory under the system temp dir, removed after each test.
# cleanup: tearDown removes the temp directory.
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
import wikilib  # noqa: E402

SCRIPT = HERE / "wiki_intake.py"


class IntakeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.wiki = self.tmp / "wiki"
        self.wiki.mkdir()
        self.src = self.tmp / "src"
        self.src.mkdir()
        self.store = self.tmp / "store"
        self.store.mkdir()
        self.fake = self.tmp / "fake-new.sh"
        self.fake.write_text('#!/bin/sh\necho "%s/blob-$$.bin"\n' % self.store)
        self.fake.chmod(0o755)
        self.config({"artifact_new": str(self.fake)})

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def config(self, d):
        (self.wiki / "wiki.json").write_text(json.dumps(d))

    def run_intake(self, *srcs):
        return subprocess.run([sys.executable, str(SCRIPT), str(self.wiki)] + [str(s) for s in srcs],
                              capture_output=True, text=True)

    def raws(self):
        return sorted((self.wiki / "raw").glob("*.md"))

    def test_capture_writes_frontmatter_and_body(self):
        f = self.src / "Notes One.md"
        f.write_text("hello\n")
        r = self.run_intake(f)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.startswith("WIKI-001 "))
        (raw,) = self.raws()
        sha = wikilib.sha256_file(f)
        self.assertEqual(raw.name, "%s-notes-one-md.md" % sha[:12])
        meta, body = wikilib.read_frontmatter(raw.read_text())
        self.assertEqual((meta["sha256"], meta["bytes"], body), (sha, "6", "hello\n"))
        self.assertRegex(meta["captured_at"], r"Z$")
        self.assertNotIn("blob", meta)

    def test_second_run_adds_nothing(self):
        f = self.src / "a.md"
        f.write_text("same")
        self.run_intake(f)
        before = self.raws()[0].read_bytes()
        r = self.run_intake(f)
        self.assertTrue(r.stdout.startswith("WIKI-002 "))
        self.assertEqual(len(self.raws()), 1)
        self.assertEqual(self.raws()[0].read_bytes(), before)

    def test_changed_source_adds_one_file(self):
        f = self.src / "a.md"
        f.write_text("v1")
        self.run_intake(f)
        f.write_text("v2")
        self.run_intake(f)
        self.assertEqual(len(self.raws()), 2)

    def test_directory_recurses_over_known_suffixes_sorted(self):
        (self.src / "sub").mkdir()
        (self.src / "b.md").write_text("b")
        (self.src / "sub" / "a.json").write_text("{}")
        (self.src / "c.xml").write_text("<c/>")
        (self.src / "skip.txt").write_text("no")
        r = self.run_intake(self.src)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.raws()), 3)
        self.assertEqual(len(r.stdout.strip().splitlines()), 3)

    def test_blob_over_limit_goes_to_store(self):
        self.config({"artifact_new": str(self.fake), "blob_limit_bytes": 10})
        f = self.src / "big.json"
        f.write_bytes(b"x" * 11)
        r = self.run_intake(f)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.startswith("WIKI-003 "))
        meta, body = wikilib.read_frontmatter(self.raws()[0].read_text())
        self.assertEqual(body, "")
        blob = Path(meta["blob"])
        self.assertEqual(blob.read_bytes(), b"x" * 11)
        self.assertEqual(blob.parent, self.store)

    def test_blob_at_limit_stays_inline(self):
        self.config({"artifact_new": str(self.fake), "blob_limit_bytes": 10})
        f = self.src / "edge.md"
        f.write_bytes(b"x" * 10)
        self.assertTrue(self.run_intake(f).stdout.startswith("WIKI-001 "))

    def test_artifact_new_failure_uses_artifact_sh(self):
        bad = self.tmp / "bad.sh"
        bad.write_text("#!/bin/sh\nexit 1\n")
        bad.chmod(0o755)
        self.config({"artifact_new": str(bad), "blob_limit_bytes": 1})
        f = self.src / "big.md"
        f.write_bytes(b"xx")
        env_root = self.tmp / "artroot"
        import os
        env = dict(os.environ, ARTIFACT_ROOT=str(env_root))
        r = subprocess.run([sys.executable, str(SCRIPT), str(self.wiki), str(f)], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("FB-004", r.stderr)
        meta, _ = wikilib.read_frontmatter(self.raws()[0].read_text())
        self.assertTrue(Path(meta["blob"].replace("~", str(Path.home()), 1)).exists() or Path(meta["blob"]).exists())

    def test_no_sources_is_usage(self):
        self.assertEqual(self.run_intake().returncode, 2)

    def test_missing_source_is_io(self):
        self.assertEqual(self.run_intake(self.src / "nope.md").returncode, 4)


if __name__ == "__main__":
    unittest.main()
