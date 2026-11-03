import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "git/git-core.symlink/hooks/prepare-commit-msg-llm"


class GitCommitHookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.capture = self.root / "captured-input"
        self.message = self.root / "message"
        self.message.write_text("# Original Git comments\n")
        fake_llm = self.bin / "llm"
        fake_llm.write_text(
            '#!/bin/sh\ncat > "$CAPTURE_FILE"\n'
            'printf "%s\\n" "$@" > "$CAPTURE_ARGS"\n'
            '[ "${FAKE_LLM_FAIL:-0}" = 0 ] || exit 2\n'
            "printf 'fix: bound generated commit context\\n'\n"
        )
        fake_llm.chmod(0o755)
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "CAPTURE_FILE": str(self.capture),
            "CAPTURE_ARGS": str(self.root / "captured-args"),
            "TERM": "dumb",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
        }
        self.env.pop("SKIP_LLM_GITHOOK", None)
        self.git("init", "-q", "-b", "fix/ISSUE-42-context")
        self.git("config", "user.name", "Hook Test")
        self.git("config", "user.email", "hook@example.invalid")
        self.git("config", "core.hooksPath", str(self.root / "no-hooks"))

    def git(self, *args):
        return subprocess.run(
            ["git", "--literal-pathspecs", *args], cwd=self.repo, env=self.env, check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )

    def stage(self, name, contents):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents if isinstance(contents, bytes) else contents.encode())
        self.git("add", "--", name)

    def run_hook(self, *args, **overrides):
        result = subprocess.run(
            ["bash", str(HOOK), str(self.message), *args], cwd=self.repo,
            env={**self.env, **overrides}, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=15,
        )
        return result

    def captured(self):
        data = self.capture.read_bytes()
        self.assertLessEqual(len(data), 65536)
        return data.decode("utf-8")

    def test_large_single_line_data_does_not_displace_source_or_small_config(self):
        self.stage("archive/observations.jsonl", '{"value":"' + "x" * 2_000_000 + '"}\n')
        self.stage("src/service.py", "def serve():\n    return 'healthy'\n")
        self.stage("catalog.json", '{"default":"example/model"}\n')

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr.decode())
        text = self.captured()
        self.assertIn("fix/ISSUE-42-context", text)
        self.assertIn("archive/observations.jsonl", text)
        self.assertIn("+def serve():", text)
        self.assertIn('+{"default":"example/model"}', text)
        self.assertIn("summary only", text)
        self.assertIn("omitted", text)
        self.assertIn("fix: bound generated commit context", self.message.read_text())

    def test_large_source_diff_is_truncated_by_bytes(self):
        self.stage("src/generated.py", "value = '" + "雪" * 100_000 + "'\n")

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr.decode())
        text = self.captured()
        self.assertIn("src/generated.py", text)
        self.assertIn("truncated", text)
        self.assertLess(len(self.capture.read_bytes()), 12_000)
        block = self.capture.read_bytes().split(b"\nFile: ", 1)[1].split(b"\nCoverage:", 1)[0]
        self.assertLessEqual(len(block) + len(b"\nFile: "), 8192)

    def test_many_paths_keep_total_budget_and_retain_late_source_changes(self):
        for index in range(450):
            self.stage(f"archive/{index:04d}-{'d' * 90}.jsonl", "{}\n")
        for index in range(12):
            self.stage(f"src/z{index:02d}.py", "value = '" + "y" * 20_000 + "'\n")

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr.decode())
        text = self.captured()
        self.assertIn("462", text)
        self.assertIn("src/z00.py", text)
        self.assertIn("+value = '", text)
        self.assertIn("omitted", text)

    def test_invalid_utf8_expansion_is_bounded_and_reported_as_truncated(self):
        self.stage("src/bytes.py", b"data = '" + b"\xff" * 3500 + b"'\n")

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr.decode())
        text = self.captured()
        self.assertIn("diff excerpt truncated", text)

    def test_binary_rename_deletion_and_unusual_names_are_safe(self):
        self.stage("old.txt", "original content\n")
        self.stage("delete.txt", "remove this content\n")
        tree = self.git("write-tree").stdout.strip()
        commit = subprocess.run(
            ["git", "commit-tree", tree], cwd=self.repo, env=self.env,
            input=b"fixture\n", stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        ).stdout.strip()
        self.git("update-ref", "HEAD", commit)
        self.git("mv", "old.txt", "renamed.txt")
        self.git("rm", "delete.txt")
        self.stage("image.bin", b"\x00\x01not model text\x00")
        unusual = "-literal\tname\n[*.py]"
        self.stage(unusual, "literal path contents\n")

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr.decode())
        text = self.captured()
        self.assertIn("old.txt", text)
        self.assertIn("renamed.txt", text)
        self.assertIn("delete.txt", text)
        self.assertIn("-remove this content", text)
        self.assertIn("image.bin", text)
        self.assertNotIn("not model text", text)
        self.assertIn("literal path contents", text)
        self.assertNotIn("\x00", text)

    def test_empty_index_and_explicit_message_do_not_call_model(self):
        result = self.run_hook()
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.capture.exists())
        self.stage("file.txt", "staged\n")
        result = self.run_hook("message")
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.capture.exists())

    def test_model_failure_preserves_original_message(self):
        self.stage("file.txt", "staged\n")
        original = self.message.read_bytes()

        result = self.run_hook(FAKE_LLM_FAIL="1")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.message.read_bytes(), original)
        self.captured()

    def test_only_staged_content_is_read_without_textconv(self):
        marker = self.root / "driver-called"
        driver = self.bin / "textconv"
        driver.write_text(f'#!/bin/sh\ntouch "{marker}"\nprintf "driver-output"\n')
        driver.chmod(0o755)
        self.git("config", "diff.fixture.textconv", str(driver))
        self.stage(".gitattributes", "*.txt diff=fixture\n")
        self.stage("file.txt", "staged-only\n")
        (self.repo / "file.txt").write_text("working-tree-only\n")

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr.decode())
        text = self.captured()
        self.assertIn("+staged-only", text)
        self.assertNotIn("working-tree-only", text)
        self.assertFalse(marker.exists())

    def test_custom_system_prompt_uses_the_same_bounded_context(self):
        system = self.home / ".config/prompts/commit-system-prompt.txt"
        system.parent.mkdir(parents=True)
        system.write_text("Use a concise commit message.")
        self.stage("source.py", "answer = 42\n")

        result = self.run_hook()

        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertIn("+answer = 42", self.captured())
        self.assertEqual(
            (self.root / "captured-args").read_text().splitlines(),
            ["-s", "Use a concise commit message."],
        )

    def test_collection_failure_does_not_call_model_or_change_message(self):
        original = self.message.read_bytes()
        result = subprocess.run(
            ["bash", str(HOOK), str(self.message)], cwd=self.root, env=self.env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.capture.exists())
        self.assertEqual(self.message.read_bytes(), original)

    def test_dispatcher_shows_collection_failure_when_helper_is_missing(self):
        self.stage("file.txt", "staged\n")
        installed = self.root / "installed-hooks"
        installed.mkdir()
        (installed / "prepare-commit-msg").symlink_to(HOOK.parent / "_dispatcher")
        (installed / "prepare-commit-msg-llm").symlink_to(HOOK)
        secrets = self.bin / "git-secrets"
        secrets.write_text("#!/bin/sh\nexit 0\n")
        secrets.chmod(0o755)
        original = self.message.read_bytes()

        result = subprocess.run(
            ["bash", str(installed / "prepare-commit-msg"), str(self.message)],
            cwd=self.repo, env=self.env, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=15,
        )

        self.assertIn(b"Failed to prepare staged commit context", result.stdout)
        self.assertFalse(self.capture.exists())
        self.assertEqual(self.message.read_bytes(), original)

    def test_dispatcher_shows_temporary_file_creation_failure(self):
        installed = self.root / "installed-hooks"
        installed.mkdir()
        (installed / "prepare-commit-msg").symlink_to(HOOK.parent / "_dispatcher")
        (installed / "prepare-commit-msg-llm").symlink_to(HOOK)
        secrets = self.bin / "git-secrets"
        secrets.write_text("#!/bin/sh\nexit 0\n")
        secrets.chmod(0o755)
        original = self.message.read_bytes()

        result = subprocess.run(
            ["bash", str(installed / "prepare-commit-msg"), str(self.message)],
            cwd=self.repo, env={**self.env, "TMPDIR": str(self.root / "missing")},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15,
        )

        self.assertIn(b"Failed to prepare staged commit context", result.stdout)
        self.assertFalse(self.capture.exists())
        self.assertEqual(self.message.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
