"""Verify the sealed operational archive before exclusive installation into a fresh AP."""
import argparse
import hashlib
import json
import os
from pathlib import PurePosixPath
import re
import stat
import tarfile

TOP = "operational69-20261103-v1"
NOFOLLOW = os.O_NOFOLLOW
DIRFLAGS = os.O_RDONLY | os.O_DIRECTORY | NOFOLLOW


def relative(name):
    if not isinstance(name, str) or not name or "\\" in name or "\x00" in name:
        raise ValueError("unsafe_member_path")
    parts = name.split("/")
    if any(p in ("", ".", "..") for p in parts) or str(PurePosixPath(name)) != name:
        raise ValueError("unsafe_member_path")
    return parts


def digest(stream):
    stream.seek(0)
    result = hashlib.file_digest(stream, "sha256").hexdigest()
    stream.seek(0)
    return result


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("duplicate_manifest_key")
        value[key] = item
    return value


def inventory(manifest):
    if manifest.get("schemaVersion") != "zoop-private-operational69-manifest-1" or manifest.get("packageVersion") != TOP:
        raise ValueError("manifest_schema")
    payload = manifest["payload"]
    files = manifest["files"]
    if len(files) != 3 or set(files) != {"README.md", "SMOKE_REPORT.json", "evidence/COPY_PROVENANCE.json"}:
        raise ValueError("other_files_invalid")
    if sum(v.get("directory") is True for v in payload.values()) != 82 or sum(not v.get("directory", False) for v in payload.values()) != 249 or manifest["archive"]["entriesVerified"] != 334:
        raise ValueError("inventory_categories_invalid")
    expected = {}
    for name, entry in payload.items():
        if name == ".":
            name = "payload"
        else:
            relative(name)
            name = "payload/" + name
        is_dir = entry.get("directory", False)
        if not isinstance(is_dir, bool):
            raise ValueError("directory_type_invalid")
        mode = entry.get("mode")
        if mode != (0o700 if is_dir else 0o600):
            raise ValueError("manifest_permissions_invalid")
        expected[f"{TOP}/{name}"] = (is_dir, entry)
    for name, entry in files.items():
        relative(name)
        expected[f"{TOP}/{name}"] = (False, entry)
    if expected.get(f"{TOP}/payload", (False,))[0] is not True:
        raise ValueError("payload_root_missing")
    for is_dir, entry in expected.values():
        if not is_dir and (type(entry.get("bytes")) is not int or entry["bytes"] < 0 or not re.fullmatch("[0-9a-f]{64}", entry.get("sha256", ""))):
            raise ValueError("file_metadata_invalid")
    return expected


def verify(tar, expected):
    seen = set()
    members = tar.getmembers()
    for member in members:
        relative(member.name)
        if member.name in seen or member.name not in expected:
            raise ValueError("duplicate_or_extra_tar_member")
        seen.add(member.name)
        is_dir, entry = expected[member.name]
        if member.type != (tarfile.DIRTYPE if is_dir else tarfile.REGTYPE) or member.sparse is not None:
            raise ValueError("tar_type_invalid")
        if member.mode != (0o700 if is_dir else 0o600):
            raise ValueError("tar_permissions_invalid")
        if not is_dir:
            with tar.extractfile(member) as stream:
                if member.size != entry["bytes"] or hashlib.file_digest(stream, "sha256").hexdigest() != entry["sha256"]:
                    raise ValueError("tar_content_mismatch")
    if seen != set(expected):
        raise ValueError("tar_inventory_mismatch")
    return members


def open_directory(path):
    path = os.fspath(path)
    if not path.startswith("/"):
        raise ValueError("destination_not_absolute")
    parts = relative(path[1:])
    fd = os.open("/", DIRFLAGS)
    try:
        for part in parts:
            child = os.open(part, DIRFLAGS, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except BaseException:
        os.close(fd)
        raise


def parent_fd(root_fd, parts):
    fd = os.dup(root_fd)
    try:
        for part in parts:
            child = os.open(part, DIRFLAGS, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except BaseException:
        os.close(fd)
        raise


def install(archive_path, manifest_path, destination, archive_sha, manifest_sha):
    os.umask(0o077)
    root = open_directory(destination)
    try:
        if os.listdir(root):
            raise ValueError("destination_occupied_preserved")
        with os.fdopen(os.open(manifest_path, os.O_RDONLY | NOFOLLOW), "rb") as source:
            if digest(source) != manifest_sha:
                raise ValueError("trusted_manifest_sha_mismatch")
            manifest = json.load(source, object_pairs_hook=unique_object)
        expected = inventory(manifest)
        with os.fdopen(os.open(archive_path, os.O_RDONLY | NOFOLLOW), "rb") as source:
            if not stat.S_ISREG(os.fstat(source.fileno()).st_mode) or digest(source) != archive_sha or manifest["archive"]["sha256"] != archive_sha or os.fstat(source.fileno()).st_size != manifest["archive"]["bytes"]:
                raise ValueError("trusted_archive_sha_mismatch")
            with tarfile.open(fileobj=source, mode="r:gz") as tar:
                members = verify(tar, expected)
                if os.listdir(root):
                    raise ValueError("destination_occupied_preserved")
                directories = set()
                for name, (is_dir, _) in expected.items():
                    parts = relative(name)
                    for size in range(1, len(parts) + (1 if is_dir else 0)):
                        directories.add(tuple(parts[:size]))
                declared_dirs = {tuple(relative(name)) for name, (is_dir, _) in expected.items() if is_dir}
                if directories != declared_dirs | {(TOP,), (TOP, "evidence")}:
                    raise ValueError("manifest_parent_inventory_invalid")
                for parts in sorted(directories, key=lambda p: (len(p), p)):
                    fd = parent_fd(root, parts[:-1])
                    try:
                        os.mkdir(parts[-1], mode=0o700, dir_fd=fd)
                    finally:
                        os.close(fd)
                for member in members:
                    if member.isdir():
                        continue
                    parts = relative(member.name)
                    parent = parent_fd(root, parts[:-1])
                    try:
                        fd = os.open(parts[-1], os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW, 0o600, dir_fd=parent)
                        with os.fdopen(fd, "wb") as output, tar.extractfile(member) as input_file:
                            size, hasher = 0, hashlib.sha256()
                            while chunk := input_file.read(1024 * 1024):
                                output.write(chunk)
                                hasher.update(chunk)
                                size += len(chunk)
                            row = expected[member.name][1]
                            if size != row["bytes"] or hasher.hexdigest() != row["sha256"]:
                                raise ValueError("installed_content_mismatch_partial_preserved")
                            output.flush()
                            os.fsync(output.fileno())
                            os.fchmod(output.fileno(), 0o400)
                            if stat.S_IMODE(os.fstat(output.fileno()).st_mode) != 0o400:
                                raise ValueError("installed_permissions_mismatch")
                    finally:
                        os.close(parent)
                if digest(source) != archive_sha:
                    raise ValueError("archive_changed_partial_preserved")
                for parts in sorted(directories, key=lambda p: (-len(p), p)):
                    fd = parent_fd(root, parts)
                    try:
                        os.fchmod(fd, 0o500)
                        if stat.S_IMODE(os.fstat(fd).st_mode) != 0o500:
                            raise ValueError("installed_permissions_mismatch")
                    finally:
                        os.close(fd)
        return {"status": "installed", "archiveSha256": archive_sha, "manifestSha256": manifest_sha, "payloadFiles": 249, "payloadDirectories": 82, "otherFiles": 3, "verifiedEntries": len(expected)}
    finally:
        os.close(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("archive", "manifest", "destination", "archive-sha256", "manifest-sha256"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    print(json.dumps(install(args.archive, args.manifest, args.destination, args.archive_sha256, args.manifest_sha256), sort_keys=True))


if __name__ == "__main__":
    main()
