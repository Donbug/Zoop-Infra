"""Bootstrap the installed read service with a closed effective environment."""
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

BASE_KEYS = {
    "ZOOP_AI_SERVICE_STATE_DIR", "ZOOP_AI_WORKER_STATE_DIR", "ZOOP_STATE_DIR",
    "ZOOP_AI_SERVICE_WORKER_COMMAND", "ZOOP_AI_SERVICE_GRANTS",
    "ZOOP_AI_SERVICE_HOST", "ZOOP_AI_SERVICE_PORT", "ZOOP_AI_SERVICE_INGESTION_COMMAND",
    "ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS", "ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS_SHA256",
}
HANDOFF_KEYS = {
    "ZOOP_AI_SERVICE_HANDOFF_COMMAND", "ZOOP_AI_HANDOFF_STATE_DIR",
    "ZOOP_AI_SERVICE_HANDOFF_CANONICAL", "ZOOP_AI_SERVICE_HANDOFF_DECISIONS",
    "ZOOP_AI_SERVICE_HANDOFF_BINDINGS", "ZOOP_AI_SERVICE_HANDOFF_EXPORTS",
    "ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS", "ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS_SHA256",
}
FIELDS = ("documentId", "documentVersion", "articleId", "articleVersion", "textSha256", "offsetUnit")


def load(path):
    return json.loads(Path(path).read_bytes())


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def selected_rows(path, selection):
    value = load(path)
    if value.get("schemaVersion") != "zoop-app-document-bindings-1":
        raise ValueError("bindings_schema")
    rows = {}
    for row in value["bindings"]:
        key = (row["documentId"], row["documentVersion"])
        if key in selection:
            if key in rows or any(not isinstance(row.get(f), str) or not row[f] for f in FIELDS):
                raise ValueError("selected_binding_invalid")
            rows[key] = {f: row[f] for f in FIELDS}
    if set(rows) != selection:
        raise ValueError("selected_binding_missing")
    return [rows[key] for key in sorted(rows)]


def check_bindings(frozen, target, selection_path, frozen_sha, expected_rows_sha):
    if sha(frozen) != frozen_sha:
        raise ValueError("frozen_bindings_changed")
    selection = load(selection_path)
    if selection.get("schemaVersion") != "zoop-document-bindings-selection-1":
        raise ValueError("selection_schema")
    keys = [(r["documentId"], r["documentVersion"]) for r in selection["versions"]]
    if not keys or len(set(keys)) != len(keys):
        raise ValueError("selection_invalid")
    required = set(keys)
    before = selected_rows(frozen, required)
    after = selected_rows(target, required)
    digest = hashlib.sha256(json.dumps(after, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
    if before != after or digest != expected_rows_sha:
        raise ValueError("selected_bindings_mismatch_requires_producer_refreeze")
    if sha(frozen) != frozen_sha:
        raise ValueError("frozen_bindings_changed")


def prepare_private(root):
    root = Path(root)
    if not root.is_absolute() or root != Path(os.path.realpath(root)):
        raise ValueError("scratch_path_invalid")
    root.mkdir(mode=0o700)
    for path in [root, *(root / name for name in ("service", "worker", "app"))]:
        if path != root:
            path.mkdir(mode=0o700)
        info = path.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError("scratch_identity_invalid")


def effective_environment(config, inherited):
    env = config["environment"]
    expected = BASE_KEYS | (HANDOFF_KEYS if config.get("handoff") else set())
    if set(env) != expected:
        raise ValueError("environment_group_invalid")
    grants = load(env["ZOOP_AI_SERVICE_GRANTS"])
    if grants.get("schemaVersion") != "zoop-ai-s1-1" or grants.get("grants") != []:
        raise ValueError("deny_all_grants_required")
    principals_raw = inherited["ZOOP_AI_SERVICE_PRINCIPALS"]
    principals = json.loads(principals_raw)
    scopes = {"observation.read", "handoff.read"} if config.get("handoff") else {"observation.read"}
    if not isinstance(principals, list) or len(principals) != 1 or principals[0].get("principal") != config["principal"] or set(principals[0].get("scopes", [])) != scopes:
        raise ValueError("reader_principal_scope_invalid")
    inventory = env["ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS"]
    inventory_sha = env["ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS_SHA256"]
    if sha(inventory) != inventory_sha:
        raise ValueError("inventory_changed")
    if config.get("handoff"):
        h = config["handoff"]
        if (env["ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS"], env["ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS_SHA256"]) != (inventory, inventory_sha):
            raise ValueError("inventory_disagrees")
        check_bindings(env["ZOOP_AI_SERVICE_HANDOFF_BINDINGS"], h["target_bindings"], h["selection"], h["frozen_sha256"], h["selected_rows_sha256"])
        expected_export = {"schemaVersion": "zoop-ai-handoff-exports-1", "handoffs": [{"principal": config["principal"], "handoffId": h["handoff_id"], "manifestDigest": h["manifest_digest"], "bundleDigest": h["bundle_digest"]}]}
        if load(env["ZOOP_AI_SERVICE_HANDOFF_EXPORTS"]) != expected_export:
            raise ValueError("handoff_allowlist_not_exact")
    return {"PATH": "/usr/local/bin:/usr/bin:/bin", "LANG": "C.UTF-8", "HOME": "/tmp", "TMPDIR": "/tmp", "PYTHONDONTWRITEBYTECODE": "1", "PYTHONUNBUFFERED": "1", **env, "ZOOP_AI_SERVICE_PRINCIPALS": principals_raw}


def main():
    os.umask(0o077)
    if os.geteuid() != 0 or os.getegid() != 0:
        raise ValueError("reviewed_uid0_contract_required")
    config = json.loads(sys.argv[1])
    env = effective_environment(config, os.environ)
    root = Path(config["scratch_root"])
    if any(env[key] != str(root / child) for key, child in [("ZOOP_AI_SERVICE_STATE_DIR", "service"), ("ZOOP_AI_WORKER_STATE_DIR", "worker"), ("ZOOP_STATE_DIR", "app")]):
        raise ValueError("scratch_roots_disagree")
    prepare_private(root)
    command = "/opt/zoop/service/.venv/bin/zoop-ai-service"
    os.execve(command, [command], env)


if __name__ == "__main__":
    main()
