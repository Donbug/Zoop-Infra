from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app"))

from stage_first47 import (  # noqa: E402
    StageError,
    extract_selected,
    parse_sums,
    verify_archive,
)


class ArchiveTests(unittest.TestCase):
    def make_fixture(self, root: Path, *, symlink: bool = False, traversal: bool = False):
        payload = b"first47\n"
        payload_sha = hashlib.sha256(payload).hexdigest()
        manifest = {
            "fileCount": 1,
            "files": [
                {
                    "path": "authority/example.json",
                    "bytes": len(payload),
                    "sha256": payload_sha,
                }
            ],
        }
        manifest_bytes = json.dumps(manifest, separators=(",", ":")).encode()
        manifest_path = root / "MANIFEST.json"
        manifest_path.write_bytes(manifest_bytes)
        archive_path = root / "fixture.tar.gz"
        with tarfile.open(archive_path, "w:gz") as archive:
            directory = tarfile.TarInfo("authority")
            directory.type = tarfile.DIRTYPE
            directory.mode = 0o700
            archive.addfile(directory)
            item = tarfile.TarInfo("authority/example.json")
            item.size = len(payload)
            item.mode = 0o600
            archive.addfile(item, io.BytesIO(payload))
            embedded = tarfile.TarInfo("MANIFEST.json")
            embedded.size = len(manifest_bytes)
            embedded.mode = 0o600
            archive.addfile(embedded, io.BytesIO(manifest_bytes))
            if symlink:
                link = tarfile.TarInfo("authority/link")
                link.type = tarfile.SYMTYPE
                link.linkname = "/etc/passwd"
                archive.addfile(link)
            if traversal:
                bad = tarfile.TarInfo("../escape")
                bad.size = 1
                archive.addfile(bad, io.BytesIO(b"x"))
        return archive_path, manifest_path, manifest

    def test_verifies_and_extracts_expected_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive_path, manifest_path, manifest = self.make_fixture(root)
            expected = verify_archive(archive_path, manifest_path, manifest)
            output = root / "output"
            output.mkdir()
            installed = extract_selected(
                archive_path,
                expected,
                output,
                lambda name: name.removeprefix("authority/")
                if name.startswith("authority/")
                else None,
            )
            self.assertEqual(installed, ["example.json"])
            self.assertEqual((output / "example.json").read_bytes(), b"first47\n")
            self.assertEqual((output / "example.json").stat().st_mode & 0o777, 0o600)

    def test_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive_path, manifest_path, manifest = self.make_fixture(
                Path(temporary), symlink=True
            )
            with self.assertRaises(StageError):
                verify_archive(archive_path, manifest_path, manifest)

    def test_rejects_parent_traversal(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive_path, manifest_path, manifest = self.make_fixture(
                Path(temporary), traversal=True
            )
            with self.assertRaises(StageError):
                verify_archive(archive_path, manifest_path, manifest)

    def test_rejects_invalid_sums(self):
        with tempfile.TemporaryDirectory() as temporary:
            sums = Path(temporary) / "SHA256SUMS"
            sums.write_text("not-a-digest  file\n", encoding="utf-8")
            with self.assertRaises(StageError):
                parse_sums(sums)


if __name__ == "__main__":
    unittest.main()
