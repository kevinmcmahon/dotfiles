import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_ai_sync(dotfiles_dir, home_dir):
    return subprocess.run(
        [str(ROOT / "scripts/ai-sync.sh")],
        cwd=ROOT,
        env={
            **os.environ,
            "DOTFILES_DIR": str(dotfiles_dir),
            "HOME": str(home_dir),
        },
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


class AiSyncTests(unittest.TestCase):
    def test_common_workflow_protocol_doc_replaces_identical_generated_copy(self):
        with tempfile.TemporaryDirectory() as tempdir:
            tmp_path = Path(tempdir)
            dotfiles_dir = tmp_path / "dotfiles"
            home_dir = tmp_path / "home"
            workflow_protocol = dotfiles_dir / "ai/docs/common/workflow-protocol.md"
            claude_doc = dotfiles_dir / "claude/docs/workflow-protocol.md"
            opencode_doc = dotfiles_dir / "opencode/docs/workflow-protocol.md"

            workflow_protocol.parent.mkdir(parents=True)
            home_dir.mkdir()
            workflow_protocol.write_text("# Workflow Protocol\n")
            claude_doc.parent.mkdir(parents=True)
            claude_doc.write_text(workflow_protocol.read_text())

            result = run_ai_sync(dotfiles_dir, home_dir)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(claude_doc.is_symlink(), result.stdout)
            self.assertEqual(
                os.readlink(claude_doc),
                "../../ai/docs/common/workflow-protocol.md",
            )
            self.assertTrue(opencode_doc.is_symlink(), result.stdout)
            self.assertEqual(
                os.readlink(opencode_doc),
                "../../ai/docs/common/workflow-protocol.md",
            )

    def test_common_workflow_protocol_doc_keeps_divergent_generated_file(self):
        with tempfile.TemporaryDirectory() as tempdir:
            tmp_path = Path(tempdir)
            dotfiles_dir = tmp_path / "dotfiles"
            home_dir = tmp_path / "home"
            workflow_protocol = dotfiles_dir / "ai/docs/common/workflow-protocol.md"
            claude_doc = dotfiles_dir / "claude/docs/workflow-protocol.md"

            workflow_protocol.parent.mkdir(parents=True)
            home_dir.mkdir()
            workflow_protocol.write_text("# Workflow Protocol\n")
            claude_doc.parent.mkdir(parents=True)
            claude_doc.write_text("# Local Edit\n")

            result = run_ai_sync(dotfiles_dir, home_dir)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(claude_doc.is_symlink())
            self.assertEqual(claude_doc.read_text(), "# Local Edit\n")
            self.assertIn("CONFLICT", result.stdout)


class AiAuditCoverageTests(unittest.TestCase):
    def test_platform_audits_check_generated_common_docs(self):
        for script in ("scripts/audit-mac.sh", "scripts/audit-linux.sh"):
            with self.subTest(script=script):
                text = (ROOT / script).read_text()

                self.assertIn("check_generated_common_ai_docs", text)
                self.assertIn("$HOME/.claude/docs", text)
                self.assertIn("$HOME/.opencode/docs", text)


if __name__ == "__main__":
    unittest.main()
