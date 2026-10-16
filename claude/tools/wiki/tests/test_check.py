#!/usr/bin/env python3
# name: test_check.py
# purpose: Unit tests for wiki_check.py: each WIKI-03x finding fires on its bad fixture and a clean wiki exits 0; a silent check lets a broken wiki through.
# inputs: none; builds a temp wiki root per test.
# outputs: unittest result on stdout; the last line is OK on success.
# writes-to: a temp directory under the system temp dir, removed after each test.
# cleanup: tearDown removes the temp directory.
import io
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import wiki_check  # noqa: E402

RAW = "---\nsource: ~/a.md\n---\nbody\n"
PAGE = "---\nid: p\n---\n# P\n\n## Contents\n\n- [A](#a)\n\n## <a id=\"a\"></a>A\n\nText [raw: r](../raw/r.md)\n"


class CheckTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        for d in ("raw", "processed", "index"):
            (self.tmp / d).mkdir()
        (self.tmp / "raw" / "r.md").write_text(RAW)
        (self.tmp / "processed" / "p.md").write_text(PAGE)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_check(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = wiki_check.main(["wiki_check.py", str(self.tmp)])
        return rc, buf.getvalue()

    def page(self, text):
        (self.tmp / "processed" / "p.md").write_text(text)

    def test_clean_wiki_exits_zero(self):
        self.assertEqual(self.run_check(), (0, "WIKI-000 ok\n"))

    def test_empty_root_is_usage(self):
        self.assertEqual(wiki_check.main(["x", ""]), 2)

    def test_missing_contents(self):
        self.page(PAGE.replace("## Contents", "## Intro"))
        rc, out = self.run_check()
        self.assertEqual(rc, 3)
        self.assertIn("WIKI-031 processed/p.md:", out)

    def test_broken_file_link(self):
        self.page(PAGE + "[x](../raw/missing.md)\n")
        self.assertIn("WIKI-032 processed/p.md:", self.run_check()[1])

    def test_broken_anchor(self):
        self.page(PAGE.replace("(#a)", "(#nope)"))
        self.assertIn("WIKI-032 processed/p.md:8", self.run_check()[1])

    def test_orphan_raw(self):
        (self.tmp / "raw" / "o.md").write_text(RAW)
        self.assertIn("WIKI-033 raw/o.md:1", self.run_check()[1])

    def test_index_citation_does_not_hide_orphan(self):
        (self.tmp / "raw" / "o.md").write_text(RAW)
        (self.tmp / "index" / "README.md").write_text("# I\n\n## Contents\n\n## Backlinks\n\n[o](../raw/o.md)\n")
        self.assertIn("WIKI-033 raw/o.md:1", self.run_check()[1])

    def test_uncited_section(self):
        self.page(PAGE + "\n## <a id=\"b\"></a>B\n\nno link\n")
        self.assertIn("WIKI-034 processed/p.md:", self.run_check()[1])

    def test_page_over_size(self):
        self.page(PAGE + "x\n" * 250)
        self.assertIn("WIKI-035 processed/p.md:", self.run_check()[1])

    def test_secret_in_raw(self):
        (self.tmp / "raw" / "r.md").write_text(RAW + "key AKIAABCDEFGHIJKLMNOP\n")
        self.assertIn("WIKI-036 raw/r.md:5", self.run_check()[1])

    def test_todo_write_left(self):
        self.page(PAGE + "TODO-WRITE\n")
        self.assertIn("WIKI-037 processed/p.md:", self.run_check()[1])

    def test_summary_and_determinism(self):
        self.page(PAGE + "TODO-WRITE\n")
        a, b = self.run_check(), self.run_check()
        self.assertEqual(a, b)
        self.assertIn("WIKI-030 check failed", a[1])

    def test_external_links_ignored(self):
        self.page(PAGE + "[e](https://example.com/x)\n")
        self.assertEqual(self.run_check()[0], 0)


if __name__ == "__main__":
    unittest.main()
