import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("release_metadata", ROOT / "scripts/release-metadata.py")
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


class ReleaseMetadataTests(unittest.TestCase):
    def test_only_stable_canonical_tags(self):
        self.assertEqual(metadata.parse_tag("v0.1.0"), "0.1.0")
        for tag in ["0.1.0", "v01.1.0", "v1.2.3-beta", "v1.2", "v1.2.3\n", "v1.2.3;echo bad"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                metadata.parse_tag(tag)

    def test_extracts_only_requested_release(self):
        changelog = "# Changelog\n\n## [Unreleased]\n- Later\n\n## [0.1.0] - 2026-09-19\n\n### Added\n- Shipping\n\n## [0.0.1] - 2026-09-01\n- Old\n"
        result = metadata.release_notes(changelog, "0.1.0")
        self.assertIn("Shipping", result)
        self.assertNotIn("Later", result)
        self.assertNotIn("Old", result)

    def test_refuses_missing_duplicate_empty_or_undated_notes(self):
        valid = "## [0.1.0] - 2026-09-19\n- Shipping\n"
        for text in ["", valid + valid, "## [0.1.0]\n- Shipping", "## [0.1.0] - 2026-09-19\n", "## [0.1.0] - 2026-02-31\n- Shipping"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                metadata.release_notes(text, "0.1.0")

    def test_mismatched_project_version_is_rejected(self):
        with self.assertRaises(ValueError):
            metadata.validate_project(ROOT, "999.99.99")


class ReleaseSafetyTests(unittest.TestCase):
    def clean_env(self):
        return {key: value for key, value in os.environ.items() if not key.startswith("APPLE_")}

    def test_missing_secrets_fail_without_running_a_command(self):
        for script, args in [("signing-keychain.sh", ["true"]), ("notarize.sh", ["missing.zip", "unused.json"])]:
            result = subprocess.run(["bash", str(ROOT / "scripts" / script), *args], env=self.clean_env(), capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing required secret", result.stderr)

    def test_keychain_is_deleted_and_search_list_restored_after_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            fake = directory / "security"
            fake.write_text('''#!/bin/bash
printf '%s\\n' "$1" >> "$SECURITY_LOG"
if [[ "$1" == list-keychains && "$#" == 3 ]]; then
  printf '    "/tmp/original keychain.keychain-db"\\n'
elif [[ "$1" == list-keychains && "$#" == 5 ]]; then
  [[ "$5" == '/tmp/original keychain.keychain-db' ]] || exit 99
  printf 'restored\\n' >> "$SECURITY_LOG"
fi
''')
            fake.chmod(0o755)
            env = self.clean_env()
            env.update(PATH=str(directory) + os.pathsep + env["PATH"], RUNNER_TEMP=str(directory), GITHUB_ENV=str(directory / "github-env"), APPLE_CERTIFICATE_BASE64="ZmFrZQ==", APPLE_CERTIFICATE_PASSWORD="fake", SECURITY_LOG=str(directory / "security.log"))
            result = subprocess.run(["bash", str(ROOT / "scripts/signing-keychain.sh"), "bash", "-c", "exit 42"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 42, result.stderr)
            log = (directory / "security.log").read_text()
            self.assertIn("delete-keychain", log)
            self.assertIn("restored", log)
            self.assertFalse(list(directory.glob("rs-writer-signing.*")))

    def test_notary_requires_exact_accepted_status(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            (directory / "app.zip").touch()
            fake = directory / "xcrun"
            fake.write_text('#!/bin/bash\nprintf \'%s\\n\' "$NOTARY_RESPONSE"\nexit "${NOTARY_EXIT:-0}"\n')
            fake.chmod(0o755)
            env = self.clean_env()
            env.update(PATH=str(directory) + os.pathsep + env["PATH"], APPLE_ID="test", APPLE_TEAM_ID="ABCDEFGHIJ", APPLE_APP_SPECIFIC_PASSWORD="test")
            for status in ["Accepted", "Invalid", "In Progress", "Rejected", "accepted", "Not Accepted", None]:
                env["NOTARY_RESPONSE"] = json.dumps({"id": "test-submission", "status": status})
                result = subprocess.run(["bash", str(ROOT / "scripts/notarize.sh"), str(directory / "app.zip"), str(directory / "result.json")], env=env, capture_output=True, text=True)
                with self.subTest(status=status):
                    self.assertEqual(result.returncode == 0, status == "Accepted")
            env["NOTARY_EXIT"] = "1"
            env["NOTARY_RESPONSE"] = json.dumps({"id": "test", "status": "Accepted"})
            result = subprocess.run(["bash", str(ROOT / "scripts/notarize.sh"), str(directory / "app.zip"), str(directory / "result.json")], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
