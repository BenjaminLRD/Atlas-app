"""Regression tests for secrets_guard.py. Run: python -m unittest .claude/hooks/test_secrets_guard.py
(or: python .claude/hooks/test_secrets_guard.py). Uses only temporary files; the
real .env files are never opened."""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HOOK = os.path.join(HERE, "secrets_guard.py")
ROOT = os.path.dirname(os.path.dirname(HERE))
B = "\\"


def run_raw(payload, cwd=ROOT, env_extra=None):
    env = dict(os.environ)
    env.pop("CLAUDE_PROJECT_DIR", None)
    env.update(env_extra or {})
    r = subprocess.run([sys.executable, HOOK], input=payload.encode("utf-8"),
                       capture_output=True, cwd=cwd, env=env)
    return r.returncode, r.stderr.decode("utf-8", "replace")


def run(tool_input, tool="Write", cwd=ROOT, env_extra=None):
    return run_raw(json.dumps({"tool_name": tool, "tool_input": tool_input,
                               "cwd": cwd}), cwd, env_extra)


class Blocked(unittest.TestCase):
    def test_protected_paths(self):
        paths = [
            ROOT + B + ".env", ROOT + B + ".env.production",
            ROOT.replace(B, "/") + "/.env", ".env", "./.env", "lib/../.env",
            ROOT + B + "lib" + B + ".." + B + ".env.production",
            ROOT + B + ".ENV", ROOT + B + ".Env.Production",
            ROOT + B + ".env.", ROOT + B + ".env ", ROOT + B + ".env . .",
            ROOT + B + ".env::$DATA", ROOT + B + ".env:stream",
            B + B + "?" + B + ROOT + B + ".env", B + B + "." + B + ROOT + B + ".env",
            ROOT + B + ".env" + B, ROOT + B + ".env" + B + ".",
            ROOT + B + ".env.local", ROOT + B + "config" + B + "prod.env",
            ROOT + B + "supabase" + B + ".env", "C:.env",
            B + B + "server" + B + "share" + B + ".env",
            ROOT + B + ("a" + B) * 150 + ".env",
            "\ud800" + B + ".env", "x\x00.env",
        ]
        for p in paths:
            with self.subTest(path=p):
                self.assertEqual(run({"file_path": p})[0], 2)

    def test_other_tools_and_keys(self):
        self.assertEqual(run({"notebook_path": ROOT + B + ".env"}, "NotebookEdit")[0], 2)
        self.assertEqual(run({"file_path": ROOT + B + ".env.production"}, "MultiEdit")[0], 2)
        self.assertEqual(run({"path": ROOT + B + ".env"})[0], 2)

    def test_block_message_names_the_reason(self):
        code, err = run({"file_path": ROOT + B + ".env"})
        self.assertEqual(code, 2)
        self.assertIn("protected secrets file", err)


class Allowed(unittest.TestCase):
    def test_ordinary_paths(self):
        paths = [
            ROOT + B + ".env.example", ".env.example", ROOT + B + ".ENV.EXAMPLE",
            ROOT + B + "lib" + B + "config" + B + "secrets_manager.dart",
            ROOT + B + "lib" + B + "main.dart", ROOT + B + ".environment",
            ROOT + B + ".envrc", ROOT + B + "docs" + B + "env.md",
            ROOT + B + "envelope.txt", ROOT + B + ".gitignore",
            ROOT + B + "my.envelope", ROOT + B + "new_dir" + B + "new_file.dart",
            ROOT + B + ".env ",  # a different file name on Windows
        ]
        for p in paths:
            with self.subTest(path=p):
                self.assertEqual(run({"file_path": p})[0], 0)

    def test_notebook_path(self):
        self.assertEqual(run({"notebook_path": ROOT + B + "a.ipynb"}, "NotebookEdit")[0], 0)


class FailClosed(unittest.TestCase):
    def assert_denied(self, result):
        code, err = result
        self.assertEqual(code, 2, err)
        self.assertIn("Blocked by secrets_guard", err)

    def test_malformed_hook_input(self):
        for raw in ["not json", "", "[]", "null", "42", '"text"']:
            with self.subTest(raw=raw):
                self.assert_denied(run_raw(raw))

    def test_tool_input_not_an_object(self):
        for bad in ["a string", ["x"], None, 7, True]:
            with self.subTest(tool_input=bad):
                self.assert_denied(run_raw(json.dumps(
                    {"tool_name": "Write", "tool_input": bad, "cwd": ROOT})))
        self.assert_denied(run_raw(json.dumps({"tool_name": "Write", "cwd": ROOT})))

    def test_file_path_not_a_non_empty_string(self):
        for bad in [123, 1.5, ["x"], {"a": 1}, None, True, "", "   "]:
            with self.subTest(file_path=bad):
                self.assert_denied(run({"file_path": bad}))

    def test_no_path_at_all(self):
        self.assert_denied(run({}))
        self.assert_denied(run({"content": "x", "old_string": "a"}))

    def test_one_bad_key_is_enough(self):
        self.assert_denied(run({"file_path": ROOT + B + "ok.dart", "notebook_path": 5}))


class HardLinks(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="guardtest_")
        self.addCleanup(shutil.rmtree, self.dir, True)

    def make(self, *parts, text="X=1"):
        path = os.path.join(self.dir, *parts)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
        return path

    def run_in(self, path, **env):
        return run({"file_path": path}, cwd=self.dir, env_extra=env)

    def test_link_to_secret_in_subdirectory(self):
        secret = self.make("supabase", "deep", ".env.production")
        link = os.path.join(self.dir, "lib", "innocent.txt")
        os.makedirs(os.path.dirname(link))
        os.link(secret, link)
        self.assertEqual(self.run_in(link)[0], 2)

    def test_link_named_like_the_example(self):
        secret = self.make(".env")
        link = os.path.join(self.dir, "sub", ".env.example")
        os.makedirs(os.path.dirname(link))
        os.link(secret, link)
        self.assertEqual(self.run_in(link)[0], 2)

    def test_project_dir_env_var_is_used(self):
        secret = self.make("a", ".env")
        link = os.path.join(self.dir, "b", "copy.txt")
        os.makedirs(os.path.dirname(link))
        os.link(secret, link)
        other_cwd = tempfile.mkdtemp(prefix="guardcwd_")
        self.addCleanup(shutil.rmtree, other_cwd, True)
        code, _ = run({"file_path": link}, cwd=other_cwd,
                      env_extra={"CLAUDE_PROJECT_DIR": self.dir})
        self.assertEqual(code, 2)

    def test_unlinked_and_new_files_are_allowed(self):
        self.make(".env")
        plain = self.make("lib", "plain.dart")
        self.assertEqual(self.run_in(plain)[0], 0)
        self.assertEqual(self.run_in(os.path.join(self.dir, "lib", "new.dart"))[0], 0)

    def test_other_hard_links_are_allowed(self):
        self.make(".env")
        a = self.make("lib", "a.txt")
        b = os.path.join(self.dir, "lib", "b.txt")
        os.link(a, b)
        self.assertEqual(self.run_in(b)[0], 0)

    def test_skipped_folders_are_not_scanned(self):
        secret = self.make("build", ".env")
        link = os.path.join(self.dir, "lib", "x.txt")
        os.makedirs(os.path.dirname(link))
        os.link(secret, link)
        self.assertEqual(self.run_in(link)[0], 0)  # documented limit

    def test_scan_limit_blocks_instead_of_guessing(self):
        spec = importlib.util.spec_from_file_location("secrets_guard_under_test", HOOK)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for i in range(5):
            self.make("lib", "f%d.txt" % i)
        linked = self.make("lib", "linked.txt")
        os.link(linked, os.path.join(self.dir, "lib", "linked2.txt"))
        mod.MAX_SCAN_ENTRIES = 2
        with self.assertRaises(mod.ScanLimit):
            mod.is_hard_link_to_protected(linked, self.dir)


if __name__ == "__main__":
    unittest.main()
