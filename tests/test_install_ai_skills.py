import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def write_executable(path, content):
    path.write_text(textwrap.dedent(content).lstrip())
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def run_install_ai_skills(dotfiles_dir, home_dir, bin_dir, extra_env=None):
    return subprocess.run(
        [str(ROOT / "scripts/install-ai-skills.sh")],
        cwd=ROOT,
        env={
            **os.environ,
            "DOTFILES_DIR": str(dotfiles_dir),
            "HOME": str(home_dir),
            "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
            "AI_SKILLS_REVIEWED_AT": "2099-01-02",
            **(extra_env or {}),
        },
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


class InstallAiSkillsTests(unittest.TestCase):
    def test_successful_github_installs_update_manifest_review_refs(self):
        with tempfile.TemporaryDirectory() as tempdir:
            tmp_path = Path(tempdir)
            dotfiles_dir = tmp_path / "dotfiles"
            home_dir = tmp_path / "home"
            bin_dir = tmp_path / "bin"
            manifest = dotfiles_dir / "ai/skills-manifest.toml"
            manifest.parent.mkdir(parents=True)
            home_dir.mkdir()
            bin_dir.mkdir()
            manifest.write_text(
                textwrap.dedent(
                    """
                    [[external]]
                    name = "example-skills"
                    source = "example/skills"
                    agents = ["codex"]
                    skills = ["example-skill"]
                    reviewed_ref = "oldoldoldoldoldoldoldoldoldoldoldoldoldoldoldold"
                    reviewed_at = "2026-06-07"
                    risk = "workflow"

                    [[external]]
                    name = "direct-url-skill"
                    source = "https://example.com/.well-known/skills/direct/SKILL.md"
                    agents = ["codex"]
                    skills = ["direct-skill"]
                    """
                ).lstrip()
            )
            write_executable(
                bin_dir / "npx",
                """
                #!/usr/bin/env bash
                exit 0
                """,
            )
            write_executable(
                bin_dir / "gh",
                """
                #!/usr/bin/env bash
                if [[ "$1" == "api" && "$2" == "repos/example/skills/commits/HEAD" ]]; then
                  printf '{"sha":"newnewnewnewnewnewnewnewnewnewnewnewnewnewnewnew"}\\n'
                  exit 0
                fi
                exit 1
                """,
            )

            result = run_install_ai_skills(dotfiles_dir, home_dir, bin_dir)

            self.assertEqual(result.returncode, 0, result.stderr)
            updated_manifest = manifest.read_text()
            self.assertIn(
                'reviewed_ref = "newnewnewnewnewnewnewnewnewnewnewnewnewnewnewnew"',
                updated_manifest,
            )
            self.assertIn('reviewed_at = "2099-01-02"', updated_manifest)
            self.assertIn('name = "direct-url-skill"', updated_manifest)
            direct_url_block = updated_manifest.split('name = "direct-url-skill"', 1)[1]
            self.assertNotIn("reviewed_ref", direct_url_block)

    def test_failed_install_does_not_update_manifest_review_ref(self):
        with tempfile.TemporaryDirectory() as tempdir:
            tmp_path = Path(tempdir)
            dotfiles_dir = tmp_path / "dotfiles"
            home_dir = tmp_path / "home"
            bin_dir = tmp_path / "bin"
            manifest = dotfiles_dir / "ai/skills-manifest.toml"
            manifest.parent.mkdir(parents=True)
            home_dir.mkdir()
            bin_dir.mkdir()
            manifest.write_text(
                textwrap.dedent(
                    """
                    [[external]]
                    name = "failing-skills"
                    source = "failing/skills"
                    agents = ["codex"]
                    skills = ["failing-skill"]
                    reviewed_ref = "oldoldoldoldoldoldoldoldoldoldoldoldoldoldoldold"
                    reviewed_at = "2026-06-07"
                    """
                ).lstrip()
            )
            write_executable(
                bin_dir / "npx",
                """
                #!/usr/bin/env bash
                exit 7
                """,
            )
            write_executable(
                bin_dir / "gh",
                """
                #!/usr/bin/env bash
                printf '{"sha":"newnewnewnewnewnewnewnewnewnewnewnewnewnewnewnew"}\\n'
                exit 0
                """,
            )

            result = run_install_ai_skills(dotfiles_dir, home_dir, bin_dir)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                'reviewed_ref = "oldoldoldoldoldoldoldoldoldoldoldoldoldoldoldold"',
                manifest.read_text(),
            )


if __name__ == "__main__":
    unittest.main()
