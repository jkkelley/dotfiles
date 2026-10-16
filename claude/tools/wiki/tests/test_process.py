#!/usr/bin/env python3
# name: test_process.py
# purpose: Unit tests for wiki_process.py: skeleton, citations, prose preserved, sources and sections update, idempotency, missing source.
# inputs: none; builds a temp wiki root with raw captures and pages.json per test.
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
SCRIPT = HERE / "wiki_process.py"


class ProcessTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.wiki = self.tmp / "wiki"
        (self.wiki / "raw").mkdir(parents=True)
        for n in ("aaa-one.md", "bbb-two.md"):
            (self.wiki / "raw" / n).write_text("x")
        self.pages = [{"id": "p1", "title": "Page One", "topic": "t", "sources": ["aaa-one.md"],
                       "sections": [{"anchor": "s1", "heading": "Sec One"}]}]
        self.save()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def save(self):
        (self.wiki / "pages.json").write_text(json.dumps(self.pages))

    def run_it(self):
        return subprocess.run([sys.executable, str(SCRIPT), str(self.wiki)], capture_output=True, text=True)

    def page(self):
        return self.wiki / "processed" / "p1.md"

    def test_skeleton_has_structure_and_citation(self):
        r = self.run_it()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("WIKI-010", r.stdout)
        t = self.page().read_text()
        self.assertTrue(t.startswith("---\nid: p1\ntitle: Page One\ntopic: t\nsources: aaa-one.md\nupdated: "))
        self.assertIn("# Page One\n\n## Contents\n\n- [Sec One](#s1)\n", t)
        self.assertIn('## <a id="s1"></a>Sec One\n\nTODO-WRITE\n\n[raw: aaa-one.md](../raw/aaa-one.md)\n', t)

    def test_rerun_is_byte_identical_and_unchanged(self):
        self.run_it()
        before = self.page().read_bytes()
        r = self.run_it()
        self.assertIn("WIKI-011", r.stdout)
        self.assertEqual(before, self.page().read_bytes())

    def test_written_prose_survives_and_sections_append(self):
        self.run_it()
        t = self.page().read_text().replace("TODO-WRITE", "Written by a human.")
        self.page().write_text(t)
        self.pages[0]["sources"].append("bbb-two.md")
        self.pages[0]["sections"].append({"anchor": "s2", "heading": "Sec Two"})
        self.save()
        r = self.run_it()
        self.assertIn("WIKI-010", r.stdout)
        n = self.page().read_text()
        self.assertIn("Written by a human.", n)
        self.assertIn("sources: aaa-one.md, bbb-two.md\n", n)
        self.assertIn("- [Sec One](#s1)\n- [Sec Two](#s2)\n", n)
        self.assertIn('## <a id="s2"></a>Sec Two\n\nTODO-WRITE\n\n[raw: aaa-one.md](../raw/aaa-one.md)\n[raw: bbb-two.md](../raw/bbb-two.md)\n', n)
        self.assertEqual(n.count("Written by a human."), 1)
        again = self.run_it()
        self.assertIn("WIKI-011", again.stdout)

    def test_missing_source_exits_3_and_writes_nothing(self):
        self.pages[0]["sources"].append("zzz-gone.md")
        self.save()
        r = self.run_it()
        self.assertEqual(r.returncode, 3)
        self.assertIn("WIKI-034 p1 zzz-gone.md", r.stdout)
        self.assertFalse(self.page().exists())

    def test_usage_and_bad_pages_json(self):
        r = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        (self.wiki / "pages.json").write_text("{nope")
        self.assertEqual(self.run_it().returncode, 4)


if __name__ == "__main__":
    unittest.main()
