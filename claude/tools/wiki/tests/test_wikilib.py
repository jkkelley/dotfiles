#!/usr/bin/env python3
# name: test_wikilib.py
# purpose: Unit tests for wikilib.py: the helpers every wiki verb relies on; a broken one corrupts every wiki that calls it.
# inputs: none; builds a temp wiki root per test.
# outputs: unittest result on stdout; the last line is OK on success.
# writes-to: a temp directory under the system temp dir, removed after each test.
# cleanup: tearDown removes the temp directory.
import json
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import wikilib  # noqa: E402


class WikiLibTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_utc_now_is_z_suffixed(self):
        self.assertRegex(wikilib.utc_now(), r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")

    def test_sha256_file_known_value(self):
        f = self.tmp / "a"
        f.write_bytes(b"abc")
        self.assertEqual(wikilib.sha256_file(f), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

    def test_slug(self):
        self.assertEqual(wikilib.slug("Hello, World!.md"), "hello-world-md")
        self.assertEqual(wikilib.slug("***"), "untitled")
        self.assertLessEqual(len(wikilib.slug("a" * 200)), 48)

    def test_frontmatter_roundtrip(self):
        meta = {"id": "x", "title": "T"}
        text = wikilib.write_frontmatter(meta, "# T\n")
        got, body = wikilib.read_frontmatter(text)
        self.assertEqual(got, meta)
        self.assertEqual(body, "# T\n")

    def test_frontmatter_absent(self):
        self.assertEqual(wikilib.read_frontmatter("# T\n"), ({}, "# T\n"))

    def test_load_config_defaults_and_override(self):
        cfg = wikilib.load_config(self.tmp)
        self.assertEqual(cfg["blob_limit_bytes"], 1048576)
        self.assertEqual(cfg["max_page_lines"], 200)
        self.assertEqual(cfg["raw_dir"], "raw")
        (self.tmp / "wiki.json").write_text(json.dumps({"raw_dir": "r", "max_page_lines": 50}))
        cfg = wikilib.load_config(self.tmp)
        self.assertEqual((cfg["raw_dir"], cfg["max_page_lines"], cfg["index_dir"]), ("r", 50, "index"))

    def test_load_config_malformed_raises(self):
        (self.tmp / "wiki.json").write_text("{")
        with self.assertRaises(ValueError):
            wikilib.load_config(self.tmp)

    def test_atomic_write_replaces_and_leaves_no_temp(self):
        p = self.tmp / "d" / "f.md"
        wikilib.atomic_write(p, "one")
        wikilib.atomic_write(p, b"two")
        self.assertEqual(p.read_text(), "two")
        self.assertEqual([x.name for x in p.parent.iterdir()], ["f.md"])

    def test_default_secret_patterns_match(self):
        pats = wikilib.secret_patterns()
        for sample in ("AKIAABCDEFGHIJKLMNOP", "-----BEGIN RSA PRIVATE KEY-----", "password = hunter2hunter2"):
            self.assertTrue(any(p.search(sample) for p in pats), sample)
        self.assertFalse(any(p.search("plain prose about tokens") for p in pats))

    def test_secret_patterns_override(self):
        (self.tmp / "secret-patterns.json").write_text(json.dumps({"patterns": ["ZZZ"]}))
        pats = wikilib.secret_patterns(self.tmp)
        self.assertEqual([p.pattern for p in pats], ["ZZZ"])
        self.assertEqual(len(wikilib.secret_patterns(self.tmp / "none")), len(wikilib.secret_patterns()))


if __name__ == "__main__":
    unittest.main()
