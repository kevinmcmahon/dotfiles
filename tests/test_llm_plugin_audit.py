import os
import re
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDITS = ("audit-linux.sh", "audit-mac.sh")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def write_stub(path, body):
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def run_audit_with_llm_plugins(script, installed_plugins):
    """Run a platform audit with a stub `llm` that reports the given plugins."""
    with tempfile.TemporaryDirectory() as tempdir:
        root = Path(tempdir)
        home = root / "home"
        home.mkdir()
        stubs = root / "stubs"
        stubs.mkdir()
        write_stub(
            stubs / "llm",
            "".join(f"echo '{plugin}'\n" for plugin in installed_plugins),
        )
        if script == "audit-linux.sh":
            # Report Linux so the audit gets past its platform guard on any host.
            write_stub(
                stubs / "uname",
                'case "$1" in -s|"") echo Linux ;; *) exec /usr/bin/uname "$@" ;; esac\n',
            )

        result = subprocess.run(
            ["bash", "--noprofile", "--norc", str(ROOT / "scripts" / script)],
            env={
                "PATH": f"{stubs}:{os.environ['PATH']}",
                "HOME": str(home),
                "USER": os.environ.get("USER", "nobody"),
            },
            capture_output=True,
            text=True,
            check=False,
        )
        return ANSI.sub("", result.stdout).splitlines()


class LlmPluginAuditTests(unittest.TestCase):
    def test_missing_llm_plugin_is_a_warning_not_a_failure(self):
        for script in AUDITS:
            with self.subTest(script=script):
                lines = run_audit_with_llm_plugins(script, ["llm-anthropic"])

                self.assertIn("  ✓ llm plugin: llm-anthropic", lines)
                self.assertIn("  ⚠ llm plugin missing: llm-mistral", lines)
                failures = [
                    line
                    for line in lines
                    if "✗" in line and "llm plugin missing" in line
                ]
                self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
