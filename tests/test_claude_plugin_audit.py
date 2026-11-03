import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDITS = ("audit-linux.sh", "audit-mac.sh")


def run_plugin_check(script, enabled, installed, *, marketplace_repo="owner/tools"):
    lines = (ROOT / "scripts" / script).read_text().splitlines(keepends=True)
    start = lines.index("check_claude_plugins() {\n")
    end = lines.index("}\n", start)
    function = "".join(lines[start : end + 1])

    with tempfile.TemporaryDirectory() as tempdir:
        root = Path(tempdir)
        dotfiles = root / "dotfiles"
        settings = dotfiles / "claude/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text(
            json.dumps(
                {
                    "enabledPlugins": enabled,
                    "extraKnownMarketplaces": {
                        "tools": {"source": {"repo": "owner/tools"}}
                    },
                }
            )
        )
        home = root / "home"
        plugins = home / ".claude/plugins"
        plugins.mkdir(parents=True)
        (plugins / "known_marketplaces.json").write_text(
            json.dumps({"tools": {"source": {"repo": marketplace_repo}}})
        )
        if installed is not None:
            (plugins / "installed_plugins.json").write_text(
                json.dumps({"plugins": {name: [{}] for name in installed}})
            )

        harness = """set -uo pipefail
FAIL=0
pass() { printf 'PASS: %s\\n' "$*"; }
fail() { printf 'FAIL: %s\\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf 'WARN: %s\\n' "$*"; }
"""
        return subprocess.run(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-c",
                harness + function + '\ncheck_claude_plugins\nexit "$FAIL"\n',
            ],
            env={
                "PATH": os.environ["PATH"],
                "HOME": str(home),
                "DOTFILES_DIR": str(dotfiles),
            },
            capture_output=True,
            text=True,
            check=False,
        )


class ClaudePluginAuditTests(unittest.TestCase):
    def test_builtin_does_not_require_a_marketplace_install(self):
        for script in AUDITS:
            with self.subTest(script=script):
                result = run_plugin_check(
                    script,
                    {"helper@tools": True, "cc-plugin-you-should-know@builtin": True},
                    ["helper@tools"],
                )
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("session", result.stdout)
                self.assertIn("/plugin", result.stdout)

    def test_builtin_only_needs_no_install_registry(self):
        for script in AUDITS:
            with self.subTest(script=script):
                result = run_plugin_check(script, {"helper@builtin": True}, None)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("Claude plugins installed", result.stdout)

    def test_missing_external_plugin_still_fails(self):
        for script in AUDITS:
            for plugin in ("missing@tools", "missing@builtin-tools"):
                with self.subTest(script=script, plugin=plugin):
                    result = run_plugin_check(
                        script, {"helper@builtin": True, plugin: True}, []
                    )
                    self.assertEqual(result.stderr, "")
                    self.assertEqual(result.returncode, 1, result.stdout)
                    self.assertIn(f"enabled but not installed: {plugin}", result.stdout)

    def test_external_plugin_requires_install_registry(self):
        for script in AUDITS:
            with self.subTest(script=script):
                result = run_plugin_check(script, {"helper@tools": True}, None)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn("Claude plugins not installed:", result.stdout)

    def test_disabled_plugin_needs_no_install_registry(self):
        for script in AUDITS:
            with self.subTest(script=script):
                result = run_plugin_check(script, {"helper@tools": False}, None)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.returncode, 0, result.stdout)

    def test_marketplace_mismatch_still_fails(self):
        for script in AUDITS:
            with self.subTest(script=script):
                result = run_plugin_check(
                    script,
                    {"helper@tools": True},
                    ["helper@tools"],
                    marketplace_repo="other/tools",
                )
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn("Claude marketplace repo mismatch:", result.stdout)


if __name__ == "__main__":
    unittest.main()
