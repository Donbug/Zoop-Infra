"""Synthetic archives only: no cloud access or original archive extraction."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import re
import sys
import tarfile
import tempfile
import unittest

SCRIPTS = Path(__file__).absolute().parents[1] / "scripts"


def module(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / (name + ".py"))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


stage = module("stage_operational69")
reader = module("reader_bootstrap")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value))
    return path


def fixture(root, mutation=None):
    payload = {".": {"directory": True, "mode": 0o700}}
    for i in range(81):
        payload[f"d{i}"] = {"directory": True, "mode": 0o700}
    content = {}
    for i in range(249):
        path = f"d{i % 81}/f{i}"
        data = f"synthetic-{i}".encode()
        payload[path] = {"bytes": len(data), "sha256": sha(data), "mode": 0o600}
        content[f"payload/{path}"] = data
    others = {name: b"synthetic metadata" for name in ("README.md", "SMOKE_REPORT.json", "evidence/COPY_PROVENANCE.json")}
    content.update(others)
    archive = root / "fixture.tar.gz"
    with tarfile.open(archive, "w:gz", format=tarfile.PAX_FORMAT) as tar:
        names = ["payload" if p == "." else "payload/" + p for p in payload]
        names += list(others)
        for name in names:
            entry = tarfile.TarInfo(f"{stage.TOP}/{name}")
            data = content.get(name)
            entry.type = tarfile.DIRTYPE if data is None else tarfile.REGTYPE
            entry.mode = 0o700 if data is None else 0o600
            entry.size = len(data) if data is not None else 0
            if mutation == "tamper" and name == "payload/d0/f0":
                data = b"X" * entry.size
            if mutation == "permissions" and name == "payload/d0/f0":
                entry.mode = 0o666
            tar.addfile(entry, io.BytesIO(data) if data is not None else None)
        if mutation in ("traversal", "link", "duplicate", "extra", "special"):
            entry = tarfile.TarInfo({"traversal": f"{stage.TOP}/../outside", "link": f"{stage.TOP}/link", "duplicate": f"{stage.TOP}/README.md", "extra": f"{stage.TOP}/extra", "special": f"{stage.TOP}/fifo"}[mutation])
            entry.mode = 0o600
            if mutation == "link":
                entry.type = tarfile.SYMTYPE
                entry.linkname = "/tmp/outside"
            if mutation == "special":
                entry.type = tarfile.FIFOTYPE
            tar.addfile(entry, io.BytesIO(b""))
    archive_bytes = archive.read_bytes()
    manifest = save(root / "MANIFEST.json", {
        "schemaVersion": "zoop-private-operational69-manifest-1", "packageVersion": stage.TOP,
        "archive": {"bytes": len(archive_bytes), "sha256": sha(archive_bytes), "entriesVerified": 334},
        "payload": payload, "files": {name: {"bytes": len(data), "sha256": sha(data)} for name, data in others.items()},
    })
    destination = root / "destination"
    destination.mkdir()
    return archive, manifest, destination, sha(archive_bytes), sha(manifest.read_bytes())


class StageTests(unittest.TestCase):
    def test_installs_real_synthetic_archive_and_refuses_reuse(self):
        with tempfile.TemporaryDirectory(dir=os.path.realpath(tempfile.gettempdir())) as tmp:
            args = fixture(Path(tmp))
            result = subprocess.run([sys.executable, "-B", str(SCRIPTS / "stage_operational69.py"), "--archive", str(args[0]), "--manifest", str(args[1]), "--destination", str(args[2]), "--archive-sha256", args[3], "--manifest-sha256", args[4]], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["verifiedEntries"], 334)
            files = [p for p in args[2].rglob("*") if p.is_file()]
            self.assertEqual(len(files), 252)
            self.assertTrue(all(stat.S_IMODE(p.stat().st_mode) == 0o400 for p in files))
            self.assertTrue(all(stat.S_IMODE(p.stat().st_mode) == 0o500 for p in args[2].rglob("*") if p.is_dir()))
            before = {str(p): p.read_bytes() for p in files}
            with self.assertRaisesRegex(ValueError, "occupied"):
                stage.install(*args)
            self.assertEqual(before, {str(p): p.read_bytes() for p in files})

    def test_rejects_tamper_traversal_links_duplicate_extra_and_bad_permissions_before_writing(self):
        for mutation in ("tamper", "traversal", "link", "duplicate", "extra", "special", "permissions"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory(dir=os.path.realpath(tempfile.gettempdir())) as tmp:
                args = fixture(Path(tmp), mutation)
                with self.assertRaises(ValueError):
                    stage.install(*args)
                self.assertEqual(list(args[2].iterdir()), [])

    def test_trusted_outer_hashes_and_occupied_destination_preserve_first47(self):
        with tempfile.TemporaryDirectory(dir=os.path.realpath(tempfile.gettempdir())) as tmp:
            root = Path(tmp)
            args = fixture(root)
            old = root / "first47"
            old.mkdir()
            sentinel = old / "archive.db"
            sentinel.write_bytes(b"existing first47")
            for changed in (3, 4):
                bad = list(args)
                bad[changed] = "0" * 64
                with self.assertRaisesRegex(ValueError, "sha_mismatch"):
                    stage.install(*bad)
                self.assertEqual(list(args[2].iterdir()), [])
            (args[2] / "partial").write_bytes(b"preserve partial")
            with self.assertRaisesRegex(ValueError, "occupied"):
                stage.install(*args)
            self.assertEqual((args[2] / "partial").read_bytes(), b"preserve partial")
            self.assertEqual(sentinel.read_bytes(), b"existing first47")
            symlink = root / "alias"
            symlink.symlink_to(old, target_is_directory=True)
            with self.assertRaises(OSError):
                stage.install(args[0], args[1], str(symlink), args[3], args[4])
            self.assertEqual(sentinel.read_bytes(), b"existing first47")


class ReaderTests(unittest.TestCase):
    def setup_config(self, root):
        grants = save(root / "grants.json", {"schemaVersion": "zoop-ai-s1-1", "grants": []})
        inv = save(root / "inventory.json", {"synthetic": True})
        env = {key: "synthetic" for key in reader.BASE_KEYS}
        env.update(ZOOP_AI_SERVICE_GRANTS=str(grants), ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS=str(inv), ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS_SHA256=sha(inv.read_bytes()))
        return {"environment": env, "principal": "synthetic-reader", "handoff": None}

    def test_private_service_worker_app_and_closed_effective_environment(self):
        with tempfile.TemporaryDirectory(dir=os.path.realpath(tempfile.gettempdir())) as tmp:
            root = Path(tmp)
            scratch = root / "profile"
            reader.prepare_private(scratch)
            self.assertEqual({p.name for p in scratch.iterdir()}, {"service", "worker", "app"})
            self.assertTrue(all(stat.S_IMODE(p.stat().st_mode) == 0o700 and p.stat().st_uid == os.geteuid() for p in [scratch, *scratch.iterdir()]))
            with self.assertRaises(FileExistsError):
                reader.prepare_private(scratch)
            config = self.setup_config(root)
            inherited = {"ZOOP_AI_SERVICE_PRINCIPALS": json.dumps([{"principal": "synthetic-reader", "scopes": ["observation.read"], "tokenSha256": ["1" * 64]}]), "OPENAI_API_KEY": "synthetic", "ZOOP_AI_SERVICE_REPLAY": "synthetic", "ZOOP_AI_ROUND_PROFILE": "synthetic", "ZOOP_AI_INGESTION_STATE_DIR": "synthetic"}
            effective = reader.effective_environment(config, inherited)
            self.assertEqual(set(effective) & set(inherited), {"ZOOP_AI_SERVICE_PRINCIPALS"})
            self.assertFalse(any("HANDOFF" in name for name in effective))
            save(root / "grants.json", {"schemaVersion": "zoop-ai-s1-1", "grants": [{"enabled": True}]})
            with self.assertRaisesRegex(ValueError, "deny_all"):
                reader.effective_environment(config, inherited)

    def test_selected_six_field_equality_accepts_extra_rows_preserving_frozen_bytes(self):
        with tempfile.TemporaryDirectory(dir=os.path.realpath(tempfile.gettempdir())) as tmp:
            root = Path(tmp)
            row = dict(zip(reader.FIELDS, ["doc-synthetic", "v1", "article-synthetic", "v1", "1" * 64, "unicode_code_point"]))
            frozen = save(root / "frozen.json", {"schemaVersion": "zoop-app-document-bindings-1", "bindings": [row]})
            frozen_bytes = frozen.read_bytes()
            target = save(root / "target.json", {"schemaVersion": "zoop-app-document-bindings-1", "bindings": [dict(row, documentId="doc-extra"), row]})
            selection = save(root / "selection.json", {"schemaVersion": "zoop-document-bindings-selection-1", "versions": [{"documentId": row["documentId"], "documentVersion": row["documentVersion"]}]})
            pin = sha(json.dumps([row], sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())
            reader.check_bindings(frozen, target, selection, sha(frozen_bytes), pin)
            config = self.setup_config(root)
            env = config["environment"]
            env.update({key: "synthetic" for key in reader.HANDOFF_KEYS})
            exports = save(root / "exports.json", {"schemaVersion": "zoop-ai-handoff-exports-1", "handoffs": [{"principal": config["principal"], "handoffId": "synthetic", "manifestDigest": "a" * 64, "bundleDigest": "b" * 64}]})
            env.update(ZOOP_AI_SERVICE_HANDOFF_BINDINGS=str(frozen), ZOOP_AI_SERVICE_HANDOFF_EXPORTS=str(exports), ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS=env["ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS"], ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS_SHA256=env["ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS_SHA256"])
            config["handoff"] = {"target_bindings": str(target), "selection": str(selection), "frozen_sha256": sha(frozen_bytes), "selected_rows_sha256": pin, "handoff_id": "synthetic", "manifest_digest": "a" * 64, "bundle_digest": "b" * 64}
            inherited = {"ZOOP_AI_SERVICE_PRINCIPALS": json.dumps([{"principal": config["principal"], "scopes": ["observation.read", "handoff.read"], "tokenSha256": ["1" * 64]}])}
            effective = reader.effective_environment(config, inherited)
            self.assertEqual(effective["ZOOP_AI_SERVICE_HANDOFF_BINDINGS"], str(frozen))
            config["handoff"]["manifest_digest"] = "c" * 64
            with self.assertRaisesRegex(ValueError, "allowlist_not_exact"):
                reader.effective_environment(config, inherited)
            config["handoff"]["manifest_digest"] = "a" * 64
            del env["ZOOP_AI_SERVICE_HANDOFF_CANONICAL"]
            with self.assertRaisesRegex(ValueError, "environment_group_invalid"):
                reader.effective_environment(config, inherited)
            save(target, {"schemaVersion": "zoop-app-document-bindings-1", "bindings": [dict(row, articleVersion="different")]})
            with self.assertRaisesRegex(ValueError, "requires_producer_refreeze"):
                reader.check_bindings(frozen, target, selection, sha(frozen_bytes), pin)
            self.assertEqual(frozen.read_bytes(), frozen_bytes)
            with self.assertRaisesRegex(ValueError, "frozen_bindings_changed"):
                reader.check_bindings(frozen, target, selection, "0" * 64, pin)


class RootBoundaryTests(unittest.TestCase):
    def test_managed_resource_allowlist_and_explicit_mock_plan_runs(self):
        root = SCRIPTS.parent
        source = "\n".join(path.read_text() for path in root.glob("*.tf"))
        resources = set(re.findall(r'(?m)^resource "([^"]+)" "([^"]+)"', source))
        self.assertEqual(resources, {
            ("aws_efs_access_point", "new"), ("aws_secretsmanager_secret", "new"), ("aws_cloudwatch_log_group", "task"),
            ("aws_security_group", "task"), ("aws_iam_role", "execution"), ("aws_iam_role", "task"),
            ("aws_iam_role_policy", "execution"), ("aws_iam_role_policy", "efs"),
            ("aws_ecs_task_definition", "reader"), ("aws_ecs_task_definition", "stage"), ("aws_ecs_task_definition", "register"),
            ("aws_ecs_service", "reader"), ("aws_service_discovery_service", "reader"),
            ("aws_vpc_security_group_ingress_rule", "reader"), ("aws_vpc_security_group_ingress_rule", "efs"), ("aws_vpc_security_group_ingress_rule", "database"),
            ("aws_vpc_security_group_egress_rule", "reader_http"), ("aws_vpc_security_group_egress_rule", "efs"), ("aws_vpc_security_group_egress_rule", "database"), ("aws_vpc_security_group_egress_rule", "https"),
        })
        self.assertIsNone(re.search(r"terraform_remote_state|provisioner|ignore_changes|secret_version|random_", source))
        self.assertIn('key          = "zoop/dev/operational69/terraform.tfstate"', source)
        tests = (root / "tests/contracts.tftest.hcl").read_text()
        runs = re.findall(r'(?m)^run "', tests)
        self.assertEqual(len(runs), 5)
        self.assertEqual(len(re.findall(r"(?m)^  command = plan$", tests)), len(runs))
        self.assertIn('mock_provider "aws"', tests)


if __name__ == "__main__":
    unittest.main()
