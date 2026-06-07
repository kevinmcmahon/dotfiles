import json
import os
import stat
import subprocess
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_command(args, *, env=None):
    return subprocess.run(
        args,
        cwd=ROOT,
        env={**os.environ, **(env or {})},
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def write_mock_curl(tmp_path, refs):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    curl_path = bin_dir / "curl"
    cases = "\n".join(
        f'  *"{source}"*) printf \'{{"sha":"{sha}"}}\\n\'; exit 0 ;;'
        for source, sha in refs.items()
    )
    curl_path.write_text(
        "#!/usr/bin/env bash\n"
        'url="${@: -1}"\n'
        'case "$url" in\n'
        f"{cases}\n"
        "  *) printf '{\"sha\":\"unknown\"}\\n'; exit 0 ;;\n"
        "esac\n"
    )
    curl_path.chmod(curl_path.stat().st_mode | stat.S_IXUSR)
    return bin_dir


class AiSkillsManifestTests(unittest.TestCase):
    def test_audit_ai_skills_reports_current_stale_and_unreviewed_entries(self):
        with self.subTest("audit"):
            import tempfile

            with tempfile.TemporaryDirectory() as tempdir:
                tmp_path = Path(tempdir)
                manifest = tmp_path / "skills-manifest.toml"
                manifest.write_text(
                    textwrap.dedent(
                        """\
                        [[external]]
                        name = "sample-external"
                        source = "owner/repo"
                        agents = ["codex"]
                        skills = ["sample-skill"]
                        reviewed_ref = "old-sha"
                        reviewed_at = "2026-06-07"
                        risk = "workflow"

                        [[watch]]
                        name = "sample-watch"
                        source = "twostraws/Swift-Agent-Skills"
                        reviewed_ref = "same-sha"
                        reviewed_at = "2026-06-07"
                        risk = "discovery-only"

                        [[watch]]
                        name = "unreviewed-watch"
                        source = "someone/new-index"
                        risk = "discovery-only"
                        """
                    )
                )
                fake_bin = write_mock_curl(
                    tmp_path,
                    {
                        "owner/repo": "new-sha",
                        "twostraws/Swift-Agent-Skills": "same-sha",
                        "someone/new-index": "brand-new-sha",
                    },
                )

                result = run_command(
                    ["scripts/audit-ai-skills.sh", "--json"],
                    env={
                        "SKILLS_MANIFEST": str(manifest),
                        "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}",
                    },
                )

                self.assertEqual(result.returncode, 0, result.stderr)
                data = json.loads(result.stdout)
                statuses = {entry["name"]: entry["status"] for entry in data["entries"]}
                self.assertEqual(
                    statuses,
                    {
                        "sample-external": "stale",
                        "sample-watch": "current",
                        "unreviewed-watch": "unreviewed",
                    },
                )

    def test_install_ai_skills_ignores_watch_entries_in_dry_run(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tempdir:
            manifest = Path(tempdir) / "skills-manifest.toml"
            manifest.write_text(
                textwrap.dedent(
                    """\
                    [[external]]
                    name = "sample-external"
                    source = "owner/repo"
                    agents = ["codex"]
                    skills = ["sample-skill"]
                    reviewed_ref = "reviewed-sha"
                    reviewed_at = "2026-06-07"
                    risk = "workflow"

                    [[watch]]
                    name = "sample-watch"
                    source = "twostraws/Swift-Agent-Skills"
                    reviewed_ref = "watch-sha"
                    reviewed_at = "2026-06-07"
                    risk = "discovery-only"
                    """
                )
            )

            result = run_command(
                ["scripts/install-ai-skills.sh", "--dry-run"],
                env={"SKILLS_MANIFEST": str(manifest)},
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("owner/repo", result.stdout)
            self.assertIn("sample-skill", result.stdout)
            self.assertNotIn("twostraws/Swift-Agent-Skills", result.stdout)

    def test_skills_manifest_documentation_defines_contract(self):
        doc = ROOT / "ai" / "skills-manifest.md"
        self.assertTrue(doc.exists())
        text = doc.read_text()
        for required in [
            "[[external]]",
            "[[watch]]",
            "[[local]]",
            "reviewed_ref",
            "reviewed_at",
            "risk",
            "scripts/install-ai-skills.sh",
            "scripts/audit-ai-skills.sh",
            "Decision Rule",
            "If you authored it or maintain it in this repo",
            "If `npx skills` should install it from elsewhere",
            "If it is useful to track but not install",
            "If it is generated or package-manager state",
        ]:
            self.assertIn(required, text)

        self.assertIn("ai/skills-manifest.md", (ROOT / "codex" / "README.md").read_text())
        self.assertIn("ai/skills-manifest.md", (ROOT / "claude" / "README.md").read_text())
