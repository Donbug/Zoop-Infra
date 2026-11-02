from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tarfile
import tempfile
from typing import BinaryIO, Iterable


OPERATION_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}\Z")


OBJECTS = {
    "delivery_manifest": {
        "key": "handoffs/first47-infra/d936941a9b57760f5a88e4c5864f8ad2da82e7e01a27ab3c15aa54e2629a2baa/MANIFEST.json",
        "version": "XTw.wGy7DP0PG23_u9T_SLAF7AYtSruR",
        "bytes": 9779,
        "sha256": "d936941a9b57760f5a88e4c5864f8ad2da82e7e01a27ab3c15aa54e2629a2baa",
    },
    "delivery_sums": {
        "key": "handoffs/first47-infra/d936941a9b57760f5a88e4c5864f8ad2da82e7e01a27ab3c15aa54e2629a2baa/SHA256SUMS",
        "version": "NyWebU7_mQsmEL1cjkRtd83bNcTpk.eQ",
        "bytes": 5311,
        "sha256": "0b4dddcee3239e3b5663f83410230744aa882af2e581ad9a628766cbd834f3d6",
    },
    "delivery_archive": {
        "key": "handoffs/first47-infra/d936941a9b57760f5a88e4c5864f8ad2da82e7e01a27ab3c15aa54e2629a2baa/DELIVERY.tar.gz",
        "version": "r.rInGDpkZePQujupHmIneYDkAgS11uH",
        "bytes": 313183,
        "sha256": "61dc905131d1e9ae6f9973cf5b078c0a23b49b328700e10b9af93c68a1c3dcf4",
    },
    "private_manifest": {
        "key": "handoffs/private-native-read/71a36db7bfa363989c781d2d6ea1a278b7dd09df648836710f75e230b07eb99f/MANIFEST.json",
        "version": "HLLRU70MT9dkBRQel3KU9XkBl2fDD7dP",
        "bytes": 41481,
        "sha256": "71a36db7bfa363989c781d2d6ea1a278b7dd09df648836710f75e230b07eb99f",
    },
    "private_archive": {
        "key": "handoffs/private-native-read/71a36db7bfa363989c781d2d6ea1a278b7dd09df648836710f75e230b07eb99f/private-native-read-with-authorities-r2.tar.gz",
        "version": ".aPHQA3G3oOrZjMSWo7bsTWdTpVqn4ik",
        "bytes": 8071892,
        "sha256": "f56e5d21c06a8076ed7b56e326bbb370b5d6cfbb35ff6ee6aabf882a815dd4d6",
    },
}


class StageError(RuntimeError):
    pass


def sha256_file(path: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            size += len(chunk)
            digest.update(chunk)
    return size, digest.hexdigest()


def validate_relative(name: str) -> PurePosixPath:
    if not name or "\\" in name:
        raise StageError(f"invalid archive path: {name!r}")
    path = PurePosixPath(name)
    if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
        raise StageError(f"unsafe archive path: {name!r}")
    return path


def expected_files(manifest: dict, private: bool = False) -> dict[str, tuple[int, str, int]]:
    result: dict[str, tuple[int, str, int]] = {}
    entries = manifest.get("files")
    if not isinstance(entries, list):
        raise StageError("manifest files must be an array")
    declared_count = manifest.get("fileCount")
    if declared_count != len(entries):
        raise StageError("manifest fileCount does not match files")
    for entry in entries:
        name = entry.get("path")
        validate_relative(name)
        if name in result:
            raise StageError(f"duplicate manifest path: {name}")
        mode_value = entry.get("mode", "0600") if private else "0600"
        try:
            mode = int(str(mode_value), 8)
        except ValueError as exc:
            raise StageError(f"invalid mode for {name}: {mode_value}") from exc
        if mode & 0o022:
            raise StageError(f"group/world writable mode for {name}")
        result[name] = (int(entry["bytes"]), str(entry["sha256"]).lower(), mode)
    return result


def allowed_directories(file_names: Iterable[str]) -> set[str]:
    allowed: set[str] = set()
    for name in file_names:
        parts = PurePosixPath(name).parts
        for index in range(1, len(parts)):
            allowed.add(PurePosixPath(*parts[:index]).as_posix())
    return allowed


def verify_archive(
    archive_path: Path,
    manifest_path: Path,
    manifest: dict,
    private: bool = False,
) -> dict[str, tuple[int, str, int]]:
    expected = expected_files(manifest, private=private)
    manifest_size, manifest_sha = sha256_file(manifest_path)
    archive_expected = dict(expected)
    archive_expected["MANIFEST.json"] = (manifest_size, manifest_sha, 0o600)
    directories = allowed_directories(archive_expected)
    seen: set[str] = set()

    with tarfile.open(archive_path, "r:gz") as archive:
        for member in archive.getmembers():
            path = validate_relative(member.name)
            name = path.as_posix()
            if name in seen:
                raise StageError(f"duplicate tar member: {name}")
            seen.add(name)
            if member.isdir():
                if name not in directories:
                    raise StageError(f"unexpected directory member: {name}")
                continue
            if not member.isfile():
                raise StageError(f"links and special members are forbidden: {name}")
            if name not in archive_expected:
                raise StageError(f"unexpected file member: {name}")
            expected_size, expected_sha, _ = archive_expected[name]
            if member.size != expected_size:
                raise StageError(f"member size mismatch: {name}")
            source = archive.extractfile(member)
            if source is None:
                raise StageError(f"cannot read member: {name}")
            digest = hashlib.sha256()
            size = 0
            while chunk := source.read(1024 * 1024):
                size += len(chunk)
                digest.update(chunk)
            if size != expected_size or digest.hexdigest() != expected_sha:
                raise StageError(f"member digest mismatch: {name}")

    expected_names = set(archive_expected) | directories
    if seen != expected_names:
        missing = sorted(expected_names - seen)
        extra = sorted(seen - expected_names)
        raise StageError(f"tar inventory mismatch: missing={missing}, extra={extra}")
    return expected


def ensure_empty_root(root: Path) -> None:
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    if root.is_symlink():
        raise StageError(f"root must not be a symlink: {root}")
    if any(root.iterdir()):
        raise StageError(f"target root is not empty: {root}")


def safe_destination(root: Path, relative: PurePosixPath) -> Path:
    current = root
    for part in relative.parts[:-1]:
        current = current / part
        if current.exists() and current.is_symlink():
            raise StageError(f"symlink parent is forbidden: {current}")
        current.mkdir(mode=0o700, exist_ok=True)
        os.chmod(current, 0o700)
    destination = root.joinpath(*relative.parts)
    if destination.exists() or destination.is_symlink():
        raise StageError(f"destination already exists: {destination}")
    return destination


def copy_member(source: BinaryIO, destination: Path, mode: int) -> None:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(destination, flags, mode)
    try:
        with os.fdopen(descriptor, "wb", closefd=False) as output:
            shutil.copyfileobj(source, output, length=1024 * 1024)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(destination, mode)
    finally:
        os.close(descriptor)


def extract_selected(
    archive_path: Path,
    expected: dict[str, tuple[int, str, int]],
    root: Path,
    selector,
) -> list[str]:
    installed: list[str] = []
    with tarfile.open(archive_path, "r:gz") as archive:
        for member in archive.getmembers():
            if not member.isfile() or member.name == "MANIFEST.json":
                continue
            selected = selector(member.name)
            if selected is None:
                continue
            relative = validate_relative(selected)
            destination = safe_destination(root, relative)
            source = archive.extractfile(member)
            if source is None:
                raise StageError(f"cannot read selected member: {member.name}")
            copy_member(source, destination, expected[member.name][2])
            installed.append(relative.as_posix())
    return installed


def parse_sums(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        digest, separator, name = line.partition("  ")
        if not separator or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise StageError("invalid SHA256SUMS line")
        validate_relative(name)
        if name in result:
            raise StageError(f"duplicate SHA256SUMS path: {name}")
        result[name] = digest
    return result


def download_object(client, bucket: str, spec: dict, destination: Path) -> None:
    response = client.get_object(Bucket=bucket, Key=spec["key"], VersionId=spec["version"])
    if response.get("VersionId") != spec["version"]:
        raise StageError(f"S3 version mismatch for {spec['key']}")
    if int(response["ContentLength"]) != spec["bytes"]:
        raise StageError(f"S3 content length mismatch for {spec['key']}")
    digest = hashlib.sha256()
    size = 0
    with destination.open("xb") as output:
        for chunk in response["Body"].iter_chunks(chunk_size=1024 * 1024):
            if not chunk:
                continue
            output.write(chunk)
            digest.update(chunk)
            size += len(chunk)
        output.flush()
        os.fsync(output.fileno())
    if size != spec["bytes"] or digest.hexdigest() != spec["sha256"]:
        raise StageError(f"download digest mismatch for {spec['key']}")


def write_result(ops_root: Path, operation_id: str, result: dict) -> None:
    directory = ops_root / "staging" / operation_id
    directory.mkdir(mode=0o700, parents=True, exist_ok=False)
    os.chmod(directory, 0o700)
    path = directory / "result.json"
    data = (json.dumps(result, sort_keys=True, separators=(",", ":")) + "\n").encode()
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        os.write(descriptor, data)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def run() -> dict:
    operation_id = os.environ.get("FIRST47_OPERATION_ID", "")
    if not OPERATION_RE.fullmatch(operation_id):
        raise StageError("FIRST47_OPERATION_ID is missing or invalid")
    bucket = os.environ.get("FIRST47_BUCKET", "zoop-dev-ai-collection-512138915880")
    delivery_root = Path(os.environ.get("FIRST47_DELIVERY_ROOT", "/mnt/zoop-first47"))
    authority_root = Path(os.environ.get("FIRST47_AUTHORITY_ROOT", "/mnt/zoop-authority"))
    archive_root = Path(os.environ.get("FIRST47_AI_ARCHIVE_ROOT", "/srv/zoop-ai-read/archive"))
    ops_root = Path(os.environ.get("FIRST47_OPS_ROOT", "/mnt/zoop-ops"))
    for root in (delivery_root, authority_root, archive_root):
        ensure_empty_root(root)

    import boto3

    client = boto3.client("s3", region_name=os.environ.get("AWS_REGION", "ap-northeast-2"))
    with tempfile.TemporaryDirectory(prefix="first47-") as temporary:
        temporary_root = Path(temporary)
        paths = {name: temporary_root / name for name in OBJECTS}
        for name, spec in OBJECTS.items():
            download_object(client, bucket, spec, paths[name])

        delivery_manifest = json.loads(paths["delivery_manifest"].read_text(encoding="utf-8"))
        private_manifest = json.loads(paths["private_manifest"].read_text(encoding="utf-8"))
        delivery_expected = verify_archive(
            paths["delivery_archive"], paths["delivery_manifest"], delivery_manifest
        )
        private_expected = verify_archive(
            paths["private_archive"], paths["private_manifest"], private_manifest, private=True
        )

        sums = parse_sums(paths["delivery_sums"])
        required_sums = {
            "MANIFEST.json": OBJECTS["delivery_manifest"]["sha256"],
            "DELIVERY.tar.gz": OBJECTS["delivery_archive"]["sha256"],
            **{name: digest for name, (_, digest, _) in delivery_expected.items()},
        }
        if sums != required_sums:
            raise StageError("SHA256SUMS inventory mismatch")

        delivery_installed = extract_selected(
            paths["delivery_archive"], delivery_expected, delivery_root, lambda name: name
        )
        authority_installed = extract_selected(
            paths["delivery_archive"],
            delivery_expected,
            authority_root,
            lambda name: name.removeprefix("authority/") if name.startswith("authority/") else None,
        )
        archive_installed = extract_selected(
            paths["private_archive"],
            private_expected,
            archive_root,
            lambda name: name.removeprefix("archive/") if name.startswith("archive/") else None,
        )

    if len(delivery_installed) != 53 or len(authority_installed) != 11 or len(archive_installed) != 23:
        raise StageError("installed file count mismatch")
    result = {
        "schemaVersion": "zoop-first47-staging-result-1",
        "status": "succeeded",
        "operationId": operation_id,
        "bucket": bucket,
        "objects": OBJECTS,
        "installed": {
            "delivery": len(delivery_installed),
            "authority": len(authority_installed),
            "archive": len(archive_installed),
        },
    }
    write_result(ops_root, operation_id, result)
    return result


def main() -> int:
    try:
        result = run()
        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception as exc:
        result = {
            "schemaVersion": "zoop-first47-staging-result-1",
            "status": "failed",
            "operationId": os.environ.get("FIRST47_OPERATION_ID", ""),
            "errorType": type(exc).__name__,
            "message": str(exc),
        }
        operation_id = result["operationId"]
        if OPERATION_RE.fullmatch(operation_id):
            try:
                write_result(
                    Path(os.environ.get("FIRST47_OPS_ROOT", "/mnt/zoop-ops")),
                    operation_id,
                    result,
                )
            except Exception as result_exc:
                result["resultPersistenceError"] = type(result_exc).__name__
        print(json.dumps(result, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
