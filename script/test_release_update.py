"""Publication failures must stop before any public release or feed mutation."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import release_update as release


class PublicationTests(unittest.TestCase):
    def fixture(self, directory):
        output = Path(directory)
        archive = output / "WakeBee-0.12.0.zip"
        archive.write_bytes(b"test archive")
        appcast = output / "appcast.xml"
        appcast.write_bytes(b"test signed feed")
        manifest = {"version": "0.12.0", "tag": "v0.12.0", "archive": archive.name,
                    "archive_sha256": release.digest(archive), "feed_sha256": release.digest(appcast),
                    "previous_feed_sha": "previous", "public_key": "public"}
        (output / "release.json").write_text(json.dumps(manifest))
        # Release tests own their notes; deleting old public release notes must
        # not break the publication fixtures or weaken the missing-notes guard.
        updates = output / "Updates"
        updates.mkdir()
        (updates / "0.12.0.html").write_text("<p>Test release notes</p>")
        root_patch = patch.object(release, "ROOT", output)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        return output

    def test_altered_archive_never_reaches_upload(self):
        with tempfile.TemporaryDirectory() as directory:
            output = self.fixture(directory)
            (output / "WakeBee-0.12.0.zip").write_bytes(b"changed archive")
            with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                    patch.object(release, "run") as run:
                with self.assertRaisesRegex(ValueError, "Prepared release changed"):
                    release.publish(argparse.Namespace(directory=output))
                run.assert_not_called()

    def test_concurrent_feed_change_never_creates_release(self):
        with tempfile.TemporaryDirectory() as directory:
            output = self.fixture(directory)
            with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                    patch.object(release, "current_feed", return_value=("newer", b"feed")), \
                    patch.object(release, "run") as run:
                with self.assertRaisesRegex(ValueError, "public feed changed"):
                    release.publish(argparse.Namespace(directory=output))
                self.assertTrue(all(call.args[0] != "gh" for call in run.call_args_list))

    def test_archive_published_before_feed_update(self):
        with tempfile.TemporaryDirectory() as directory:
            output = self.fixture(directory)
            with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                    patch.object(release, "current_feed", return_value=("previous", b"feed")), \
                    patch.object(release, "run") as run:
                release.publish(argparse.Namespace(directory=output))
                operations = [call for call in run.call_args_list if call.args[0] == "gh"]
                self.assertEqual([call.args[1:3] for call in operations],
                                 [("release", "create"), ("release", "edit"), ("api", "--method")])
                payload = json.loads(operations[-1].kwargs["input"])
                self.assertEqual(payload["sha"], "previous")
                self.assertEqual(payload["branch"], "main")
                create = operations[0].args
                self.assertEqual(create[create.index("--notes-file") + 1], output / "Updates/0.12.0.html")

    def test_tester_release_is_not_marked_as_latest_stable(self):
        with tempfile.TemporaryDirectory() as directory:
            output = self.fixture(directory)
            with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                    patch.object(release, "current_feed", return_value=("previous", b"feed")), \
                    patch.object(release, "run") as run:
                release.publish(argparse.Namespace(directory=output, prerelease=True))
                edit = next(call for call in run.call_args_list if call.args[:3] == ("gh", "release", "edit"))
                self.assertIn("--prerelease", edit.args)
                self.assertIn("--latest=false", edit.args)

    def test_missing_notes_never_creates_release(self):
        with tempfile.TemporaryDirectory() as directory:
            output = self.fixture(directory)
            (output / "Updates/0.12.0.html").unlink()
            with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                    patch.object(release, "current_feed", return_value=("previous", b"feed")), \
                    patch.object(release, "run") as run:
                with self.assertRaisesRegex(ValueError, "Release notes were not found"):
                    release.publish(argparse.Namespace(directory=output))
                self.assertFalse(any(call.args[0] == "gh" for call in run.call_args_list))

    def test_explicit_notes_are_used_without_default_notes(self):
        with tempfile.TemporaryDirectory() as directory:
            output = self.fixture(directory)
            (output / "Updates/0.12.0.html").unlink()
            notes = output / "installation notes.md"
            notes.write_text("Test installation instructions")
            with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                    patch.object(release, "current_feed", return_value=("previous", b"feed")), \
                    patch.object(release, "run") as run:
                release.publish(argparse.Namespace(directory=output, notes_file=notes))
                create = next(call.args for call in run.call_args_list if call.args[:3] == ("gh", "release", "create"))
                self.assertEqual(create[create.index("--notes-file") + 1], notes.resolve())

    def test_failed_release_creation_or_promotion_never_updates_feed(self):
        for stage in ("create", "edit"):
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as directory:
                output = self.fixture(directory)
                def fail_release(*args, **kwargs):
                    if args[:3] == ("gh", "release", stage):
                        raise subprocess.CalledProcessError(1, args)
                with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                        patch.object(release, "current_feed", return_value=("previous", b"feed")), \
                        patch.object(release, "run", side_effect=fail_release) as run:
                    with self.assertRaises(subprocess.CalledProcessError):
                        release.publish(argparse.Namespace(directory=output))
                    self.assertFalse(any(call.args[:2] == ("gh", "api") for call in run.call_args_list))

    def test_failed_signature_or_notarization_check_never_creates_release(self):
        for stage in (release.TOOLS / "sign_update", "xcrun"):
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as directory:
                output = self.fixture(directory)
                def fail_verification(*args, **kwargs):
                    if args[0] == stage:
                        raise subprocess.CalledProcessError(1, args)
                with patch.object(release, "configuration", return_value={"SUPublicEDKey": "public"}), \
                        patch.object(release, "current_feed", return_value=("previous", b"feed")), \
                        patch.object(release, "run", side_effect=fail_verification) as run:
                    with self.assertRaises(subprocess.CalledProcessError):
                        release.publish(argparse.Namespace(directory=output))
                    self.assertFalse(any(call.args[0] == "gh" for call in run.call_args_list))


if __name__ == "__main__":
    unittest.main()
