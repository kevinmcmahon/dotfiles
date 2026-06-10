import os
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PplxSearchTests(unittest.TestCase):
    def test_health_check_works_with_system_python_path(self):
        env = {
            **os.environ,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "PERPLEXITY_API_KEY": "pplx-test-key",
        }

        scripts = [
            ROOT / "ai/skills/codex/perplexity/pplx-search",
            ROOT / "ai/skills/claude/perplexity/pplx-search",
        ]

        for script in scripts:
            with self.subTest(script=script):
                result = subprocess.run(
                    [str(script), "--health"],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )

                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("- status: ok", result.stdout)


if __name__ == "__main__":
    unittest.main()
