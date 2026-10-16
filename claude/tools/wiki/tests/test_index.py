#!/usr/bin/env python3
# name: test_index.py
# purpose: Unit tests for wiki_index.py: structure, topic map, backlinks, determinism, empty and missing input.
# inputs: none; builds a temp wiki root with processed pages per test.
# outputs: unittest result on stdout; the last line is OK on success.
# writes-to: a temp directory under the system temp dir, removed after each test.
# cleanup: tearDown removes the temp directory.
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
SCRIPT = HERE / "wiki_index.py"

PAGE = ('---\nid: %s\ntitle: %s\ntopic: %s\nsources: %s\nupdated: 2026-10-16\n---\n# %s\n\n## Contents\n\n- [A](#a)\n\n'
        '## <a id="a"></a>A\n\nbody\n\n## <a id="b"></a>B\n\nbody\n')


class IndexTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.wiki = self.tmp / "wiki"
        (self.wiki / "processed").mkdir(parents=True)
        self.add("p2", "Second", "beta", "r1.md, r2.md")
        self.add("p1", "First", "alpha", "r1.md")
        self.add("p3", "Third", "alpha", "r2.md")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def add(self, pid, title, topic, sources):
        (self.wiki / "processed" / (pid + ".md")).write_text(PAGE % (pid, title, topic, sources, title))

    def run_it(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT)] + list(args or [str(self.wiki)]), capture_output=True, text=True)

    def index(self):
        return (self.wiki / "index" / "README.md").read_text()

    def test_writes_index_and_code(self):
        r = self.run_it()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("WIKI-020", r.stdout)
        t = self.index()
        self.assertTrue(t.startswith("# Index\n\n## Contents\n\n"))
        self.assertIn("| [p1](../processed/p1.md) | First | 2 |", t)
        self.assertLess(t.index("[p1]"), t.index("[p2]"))

    def test_topic_map_groups_and_sorts(self):
        self.run_it()
        t = self.index()
        self.assertIn("### alpha\n\n- [p1](../processed/p1.md) - First\n- [p3](../processed/p3.md) - Third\n", t)
        self.assertLess(t.index("### alpha"), t.index("### beta"))

    def test_backlinks_per_raw_sorted(self):
        self.run_it()
        t = self.index()
        self.assertIn("### [r1.md](../raw/r1.md)\n\n- [p1](../processed/p1.md)\n- [p2](../processed/p2.md)\n", t)
        self.assertLess(t.index("### [r1.md]"), t.index("### [r2.md]"))

    def test_rerun_is_byte_identical_and_untouched(self):
        self.run_it()
        first = self.index()
        mtime = (self.wiki / "index" / "README.md").stat().st_mtime_ns
        self.assertEqual(self.run_it().returncode, 0)
        self.assertEqual(self.index(), first)
        self.assertEqual((self.wiki / "index" / "README.md").stat().st_mtime_ns, mtime)

    def test_no_args_and_empty_root_are_usage(self):
        self.assertEqual(self.run_it("").returncode, 2)
        self.assertEqual(subprocess.run([sys.executable, str(SCRIPT)], capture_output=True).returncode, 2)

    def test_missing_processed_dir_is_io(self):
        shutil.rmtree(self.wiki / "processed")
        self.assertEqual(self.run_it().returncode, 4)

    def test_custom_dirs_from_config(self):
        (self.wiki / "wiki.json").write_text('{"index_dir": "ix/deep", "processed_dir": "processed"}')
        self.run_it()
        self.assertIn("(../../processed/p1.md)", (self.wiki / "ix" / "deep" / "README.md").read_text())


if __name__ == "__main__":
    unittest.main()
