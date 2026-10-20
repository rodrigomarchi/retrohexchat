"""The CI cache: a check runs again exactly when something it reads changed."""

from __future__ import annotations

import contextlib
import io
import os
import tempfile
import unittest

import ci_cache


class CacheTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.tmp.name, "repo")
        self.stamps = os.path.join(self.tmp.name, "stamps")
        os.makedirs(os.path.join(self.root, "src", "deep"))
        self.write("src/a.txt", "a")
        self.write("src/deep/b.txt", "b")
        self.write("out.txt", "built")
        self.calls = []

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, body):
        with open(os.path.join(self.root, rel), "w") as handle:
            handle.write(body)

    def runner(self, status=0, during=None):
        def call(command, cwd):
            self.calls.append((command, cwd))
            if during:
                during()
            return status

        return call

    def check(self, runner=None, command=("check",), inputs=("src", "out.txt"), force=False):
        with contextlib.redirect_stdout(io.StringIO()):
            return ci_cache.run("demo", list(inputs), list(command), root=self.root, stamps=self.stamps,
                                runner=runner or self.runner(), force=force)

    def test_first_run_runs_and_a_second_with_the_same_inputs_does_not(self):
        self.assertEqual(self.check(), 0)
        self.assertEqual(self.check(), 0)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.calls[0], (["check"], self.root))

    def test_a_changed_source_runs_again(self):
        self.check()
        self.write("src/deep/b.txt", "changed")
        self.check()
        self.assertEqual(len(self.calls), 2)

    def test_a_changed_output_runs_again(self):
        self.check()
        self.write("out.txt", "hand edited")
        self.check()
        self.assertEqual(len(self.calls), 2)

    def test_a_new_or_removed_file_runs_again(self):
        self.check()
        self.write("src/new.txt", "")
        self.check()
        os.remove(os.path.join(self.root, "src", "a.txt"))
        self.check()
        self.assertEqual(len(self.calls), 3)

    def test_a_renamed_file_runs_again(self):
        self.check()
        os.rename(os.path.join(self.root, "src", "a.txt"), os.path.join(self.root, "src", "c.txt"))
        self.check()
        self.assertEqual(len(self.calls), 2)

    def test_a_different_command_runs_again(self):
        self.check()
        self.check(command=("check", "--strict"))
        self.assertEqual(len(self.calls), 2)

    def test_a_failure_is_never_remembered(self):
        self.assertEqual(self.check(runner=self.runner(status=1)), 1)
        self.assertEqual(self.check(runner=self.runner(status=1)), 1)
        self.assertEqual(len(self.calls), 2)

    def test_an_edit_during_the_run_is_not_blessed(self):
        self.check(runner=self.runner(during=lambda: self.write("src/a.txt", "mid-run")))
        self.check()
        self.assertEqual(len(self.calls), 2)

    def test_force_runs_even_when_unchanged(self):
        self.check()
        self.check(force=True)
        self.assertEqual(len(self.calls), 2)

    def test_interpreter_caches_are_not_inputs(self):
        self.check()
        os.makedirs(os.path.join(self.root, "src", "__pycache__"))
        self.write("src/__pycache__/a.pyc", "bytecode")
        self.write("src/.DS_Store", "finder")
        self.check()
        self.assertEqual(len(self.calls), 1)


if __name__ == "__main__":
    unittest.main()
