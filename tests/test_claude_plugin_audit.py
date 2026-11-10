import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIT_LIB = ROOT / "scripts/lib/audit.sh"
AUDITS = ("audit-linux.sh", "audit-mac.sh")


def run_plugin_check(enabled, installed, *, marketplace_repo="owner/tools"):
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

        return subprocess.run(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-c",
                'set -uo pipefail\nsource "$1"\ncheck_claude_plugins\nexit "$FAIL"\n',
                "bash",
                str(AUDIT_LIB),
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
        result = run_plugin_check(
            {"helper@tools": True, "cc-plugin-you-should-know@builtin": True},
            ["helper@tools"],
        )
        self.assertEqual(result.stderr, "")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("session", result.stdout)
        self.assertIn("/plugin", result.stdout)

    def test_builtin_only_needs_no_install_registry(self):
        result = run_plugin_check({"helper@builtin": True}, None)
        self.assertEqual(result.stderr, "")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("Claude plugins installed", result.stdout)

    def test_missing_external_plugin_still_fails(self):
        for plugin in ("missing@tools", "missing@builtin-tools"):
            with self.subTest(plugin=plugin):
                result = run_plugin_check({"helper@builtin": True, plugin: True}, [])
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn(f"enabled but not installed: {plugin}", result.stdout)

    def test_external_plugin_requires_install_registry(self):
        result = run_plugin_check({"helper@tools": True}, None)
        self.assertEqual(result.stderr, "")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Claude plugins not installed:", result.stdout)

    def test_disabled_plugin_needs_no_install_registry(self):
        result = run_plugin_check({"helper@tools": False}, None)
        self.assertEqual(result.stderr, "")
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_marketplace_mismatch_still_fails(self):
        result = run_plugin_check(
            {"helper@tools": True},
            ["helper@tools"],
            marketplace_repo="other/tools",
        )
        self.assertEqual(result.stderr, "")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Claude marketplace repo mismatch:", result.stdout)


class AuditLibraryTests(unittest.TestCase):
    def test_sourcing_library_has_no_side_effects(self):
        result = subprocess.run(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-c",
                'set -uo pipefail\nsource "$1"\n',
                "bash",
                str(AUDIT_LIB),
            ],
            env={"PATH": os.environ["PATH"], "HOME": "/nonexistent"},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def test_sourcing_library_initializes_counters_to_zero(self):
        result = subprocess.run(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-c",
                'set -uo pipefail\nsource "$1" >/dev/null 2>&1 || exit 99\nprintf "%s %s %s" "$PASS" "$FAIL" "$WARN"\n',
                "bash",
                str(AUDIT_LIB),
            ],
            env={"PATH": os.environ["PATH"], "HOME": "/nonexistent"},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "0 0 0")
        self.assertEqual(result.stderr, "")

    def test_platform_audits_source_library_instead_of_defining_helpers(self):
        for script in AUDITS:
            with self.subTest(script=script):
                text = (ROOT / "scripts" / script).read_text()
                self.assertIn("lib/audit.sh", text)
                for helper in (
                    "pass() {",
                    "check_symlink() {",
                    "check_claude_plugins() {",
                    "check_perplexity_skill() {",
                ):
                    self.assertNotIn(helper, text)


if __name__ == "__main__":
    unittest.main()
