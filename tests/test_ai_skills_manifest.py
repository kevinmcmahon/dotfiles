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

    gh_path = bin_dir / "gh"
    gh_path.write_text(
        "#!/usr/bin/env bash\n"
        "printf 'gh unavailable in this fixture\\n' >&2\n"
        "exit 1\n"
    )
    gh_path.chmod(gh_path.stat().st_mode | stat.S_IXUSR)

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


def write_mock_gh_and_failing_curl(tmp_path, refs):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    gh_path = bin_dir / "gh"
    cases = "\n".join(
        f'  *"repos/{source}/commits/HEAD"*) printf \'{{"sha":"{sha}"}}\\n\'; exit 0 ;;'
        for source, sha in refs.items()
    )
    gh_path.write_text(
        "#!/usr/bin/env bash\n"
        'args="$*"\n'
        'case "$args" in\n'
        f"{cases}\n"
        "  *) printf 'unexpected gh args: %s\\n' \"$args\" >&2; exit 1 ;;\n"
        "esac\n"
    )
    gh_path.chmod(gh_path.stat().st_mode | stat.S_IXUSR)

    curl_path = bin_dir / "curl"
    curl_path.write_text(
        "#!/usr/bin/env bash\n"
        "printf 'curl should not be called when gh succeeds\\n' >&2\n"
        "exit 99\n"
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

    def test_audit_ai_skills_prefers_authenticated_gh_api_over_curl(self):
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
                    reviewed_ref = "gh-sha"
                    reviewed_at = "2026-06-07"
                    risk = "workflow"
                    """
                )
            )
            fake_bin = write_mock_gh_and_failing_curl(tmp_path, {"owner/repo": "gh-sha"})

            result = run_command(
                ["scripts/audit-ai-skills.sh", "--json"],
                env={
                    "SKILLS_MANIFEST": str(manifest),
                    "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}",
                },
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(result.stdout)
            self.assertEqual(data["entries"][0]["latest_ref"], "gh-sha")
            self.assertEqual(data["entries"][0]["status"], "current")

    def test_audit_ai_skills_default_output_is_grouped_for_humans(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tempdir:
            tmp_path = Path(tempdir)
            manifest = tmp_path / "skills-manifest.toml"
            manifest.write_text(
                textwrap.dedent(
                    """\
                    [[external]]
                    name = "stale-skill"
                    source = "owner/stale"
                    agents = ["codex"]
                    skills = ["stale-skill"]
                    reviewed_ref = "old-sha"
                    reviewed_at = "2026-06-07"
                    risk = "workflow"

                    [[external]]
                    name = "current-skill"
                    source = "owner/current"
                    agents = ["codex"]
                    skills = ["current-skill"]
                    reviewed_ref = "same-sha"
                    reviewed_at = "2026-06-07"
                    risk = "workflow"

                    [[external]]
                    name = "url-skill"
                    source = "https://example.com/SKILL.md"
                    agents = ["codex"]
                    skills = ["url-skill"]
                    """
                )
            )
            fake_bin = write_mock_curl(
                tmp_path,
                {
                    "owner/stale": "new-sha",
                    "owner/current": "same-sha",
                },
            )

            result = run_command(
                ["scripts/audit-ai-skills.sh"],
                env={
                    "SKILLS_MANIFEST": str(manifest),
                    "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}",
                },
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Summary: 1 current, 1 stale, 1 unsupported", result.stdout)
            self.assertIn("Needs attention", result.stdout)
            self.assertIn("stale       external stale-skill", result.stdout)
            self.assertIn("reviewed old-sha -> latest new-sha", result.stdout)
            self.assertIn("unsupported external url-skill", result.stdout)
            self.assertIn("Current", result.stdout)
            self.assertIn("external current-skill", result.stdout)
            self.assertNotIn("(reviewed=", result.stdout)

    def test_audit_ai_skills_verbose_output_shows_progressive_detail(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tempdir:
            tmp_path = Path(tempdir)
            manifest = tmp_path / "skills-manifest.toml"
            manifest.write_text(
                textwrap.dedent(
                    """\
                    [[external]]
                    name = "current-skill"
                    source = "owner/current"
                    agents = ["codex"]
                    skills = ["current-skill"]
                    reviewed_ref = "1234567890abcdef"
                    reviewed_at = "2026-06-07"
                    risk = "workflow"
                    notes = "Review upstream diff before updating."
                    """
                )
            )
            fake_bin = write_mock_curl(tmp_path, {"owner/current": "1234567890abcdef"})

            result = run_command(
                ["scripts/audit-ai-skills.sh", "--verbose"],
                env={
                    "SKILLS_MANIFEST": str(manifest),
                    "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}",
                },
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("source: owner/current", result.stdout)
            self.assertIn("reviewed_ref: 1234567890abcdef", result.stdout)
            self.assertIn("latest_ref:   1234567890abcdef", result.stdout)
            self.assertIn("reviewed_at: 2026-06-07", result.stdout)
            self.assertIn("risk: workflow", result.stdout)
            self.assertIn("notes: Review upstream diff before updating.", result.stdout)

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
