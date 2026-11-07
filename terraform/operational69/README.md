# Operational69 private readers

This additive dev root prepares four isolated readers for the existing operational69 package. Its S3 state key is **`zoop/dev/operational69/terraform.tfstate`**, in an infrastructure-owner-confirmed bucket. Use the default workspace. The bucket is a required backend input; the shared dev state is a different deployment boundary.

## Ownership

The root owns three EFS access points, four reader task definitions and desired-zero services, four Cloud Map service entries, one staging task definition, four registration task families, six IAM roles and their inline policies, three task security groups and dedicated log groups, two secret containers, and new individual EFS/RDS security-group rule objects. It reuses approved shared IDs through metadata reads and references. Existing ECS services, APs, filesystem policy, namespace, VPC, database, repositories and secrets remain with their existing owner. A name collision must stop the plan review rather than trigger import or a renamed duplicate.

| Task | Read-only EFS | Writable EFS |
| --- | --- | --- |
| Reader | New archive/authority/control; existing first47 archive/authority | Private task-local scratch only |
| Stage | Existing first47 operations | New archive |
| Operator | New authority; existing first47 authority | New control; existing artifacts |

Old routes retain `/srv/zoop-ai-read/archive` and `/mnt/zoop-authority`. New routes use `/srv/zoop-op69/archive`, `/mnt/zoop-op69-authority`, and `/mnt/zoop-op69-control`. The payload is `/srv/zoop-op69/archive/operational69-20261103-v1/payload`. Retain historical source-registry `inputRoot` strings and frozen file bytes when materializing the reviewed inventory; rewrite only approved operational routes.

EFS grants are AP-constrained `ClientMount`, with `ClientWrite` only for the listed writable APs. Access points enforce nonzero POSIX identities; container UID0 does not imply `ClientRootAccess`. Infrastructure must confirm that the shared EFS policy and any customer-managed encryption keys permit the new roles without transferring policy ownership.

## Required real inputs

`variables.tf` is the input reference. Every deployment input is required; profile `handoff` groups are optional complete objects.

- `expected_account_id`, `aws_region`: approved target account and fixed dev region.
- `existing`: VPC, two private subnets, cluster ARN, existing private namespace ID, encrypted EFS, shared EFS/RDS SGs, and four distinct existing AP IDs. Confirm the namespace is `zoop-dev.internal` in the same VPC; confirm AP identities and roots match the table above before approval.
- `images`: approved full ECR `repository@sha256` reader and operator pins with matching repository ARNs. Repository metadata is checked; Terraform does not inspect image contents.
- `reader_python`: exact installed interpreter path. The expected candidate layout is `/opt/zoop/service/.venv/bin/python`; its actual execution remains an image-preflight requirement. Installed ingestion, worker, handoff and service CLI paths are explicit in `reader.tf` and the bootstrap.
- `database`: real RDS endpoint/name, existing DB credentials and CSRF secret ARNs, CSRF key ID, and exact customer-managed decrypt-key ARNs if applicable. Terraform reads secret metadata only.
- `archive`: real existing operations-mount tar/manifest paths and independently trusted SHA-256 pins for both files. The external manifest is not inside the tar.
- `authority`: actual materialized inventory path/SHA pair, S1 deny-all grants path, independent operator authority entry, and matching principal name. Preserve the existing serving delegates. Paths live under the independent authority mount.
- `profiles`: actual registration request/fresh result and exact bindings selection/fresh output/result paths for `existing2`, `six`, `three`, `eu11`. Every path is a distinct normalized profile control path. Path existence, current grants, DB schema readiness and fresh destinations are operational preflight conditions.

Keep real backend/tfvars and saved plans private and outside version control. The example files are deliberately nondeployable; tests contain format-valid synthetic IDs/hashes confined to the mocked test scope.

## Executable task contracts

Readers explicitly run as `0:0` with a read-only root filesystem. The embedded stdlib bootstrap creates fresh private `service`, `worker` and `app` directories under `/var/lib/zoop-op69/<profile>` on task-scoped ephemeral storage. `/tmp` is a separate writable volume. It executes the installed service CLI only after rebuilding a closed effective environment: image round/chat/live/model/replay/provider-key and singular ingestion settings are discarded. It verifies the inventory SHA, empty S1 grants and exact reader principal scopes. Observation-only principals need `observation.read`; a later handoff revision needs exactly `observation.read` and `handoff.read`.

Scripts are delivered verbatim in task-definition entry points using `file()`, with hashes exposed for review. They are not paths on an operator laptop. Review the rendered command length against ECS task-definition limits, and verify the exact interpreter, CLI origins, UID0 and mounts against the approved image before starting any task. Local script tests do not establish cloud compatibility.

The stage task verifies the trusted outer archive and external-manifest hashes before any installation. It checks all **334 tar entries: 249 payload files, 82 payload directories and three other files**, with exact membership, file bytes/hashes, private input modes and safe regular-file/directory types. It retains the package top directory and creates structural parents, uses directory-relative no-follow exclusive writes, and installs files at `0400` and directories at `0500`. The destination AP root must already exist and be empty. Any occupied root, including a partial earlier install, is refused and preserved. Installation failures preserve partial evidence; remediation needs separate review and a genuinely fresh destination. Stage only into the new archive AP, never first47. Success is emitted to task logs with hashes and category counts.

The four registration task definitions run registration only over the HTTP observation client. `bindings_export_overrides` contains complete command overrides for a **separate export-only JVM** in the same corresponding family. Review each override and fresh selection/output/result path before RunTask. Export uses `scope=available`, exact selection and no HTTP observation client. The operator entry point rebuilds its environment with only the selected command's public settings and required injected secrets. Both processes are non-web, Flyway-off, DDL-validate, SQL-init-never, graph-source-none, and keep all other AI/import/activation paths disabled. HTTP registration and bindings export leave unused Java ingestion CLI settings unset.

### Target-binding equality and later handoff revision

Process profiles in order **existing2 → six → three → eu11**, each registration followed by a separate export: four plus four processes. Preserve exported target bindings as separate evidence. Compare selected rows against frozen bindings on exactly `documentId`, `documentVersion`, `articleId`, `articleVersion`, `textSha256`, `offsetUnit`. Required selected-row identities must match, not merely counts 2/5/2/10. Export formatting or extra unselected rows alone do not require producer re-freeze.

Always retain the frozen bindings file and its raw-byte SHA. A selected-row mismatch stops that profile and requires separately approved genuine producer re-freeze with new handoff pins. Do not rewrite historical manifests or relabel old pins. The later optional complete `handoff` input records both the frozen raw SHA and the SHA of selected target rows: sorted by `(documentId, documentVersion)`, six fields only, UTF-8 JSON with sorted keys, separators `,`/`:`, `ensure_ascii=False`, without trailing newline. The bootstrap verifies equality and both pins before service startup. Service configuration still references the original frozen bindings file. Its complete handoff group shares the observation inventory path/SHA and verifies an exact one-entry allowlist containing the principal, handoff ID and canonical manifest/bundle digests. Canonical digests are not newline-bearing manifest file hashes.

## Offline checks

With the approved Terraform 1.16.5 tool and existing AWS 6.29.0 provider package available, use an isolated copy/data directory, no AWS credentials/profile and metadata disabled. `init -backend=false` still prepares provider plugins; use the reviewed cache/mirror and `-lockfile=readonly`.

```sh
terraform -chdir=terraform/operational69 fmt -check -recursive
terraform -chdir=terraform/operational69 init -backend=false -input=false -lockfile=readonly
terraform -chdir=terraform/operational69 validate -no-color
AWS_EC2_METADATA_DISABLED=true terraform -chdir=terraform/operational69 test -no-color
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s terraform/operational69/tests -p 'test_*.py' -v
```

Every Terraform test run is explicitly `command = plan` and uses a fully mocked AWS provider. Mocked IAM JSON is a schema fixture, not rendered-policy or authorization evidence; assertions inspect authored statements. These checks are **mocked Terraform contract plans**, not actual AWS plans. Stdlib tests construct real synthetic tar archives and exercise integrity/refusal, private bootstrap/sanitization and selected-binding equality. They do not extract the original package.

## Actual AWS plan and execution approvals

An actual plan requires approved backend ownership/bucket and all real inputs, authorized metadata access and permission to acquire/release the new `.tflock` object. Normal planning may write the lock object. Confirm the default workspace and exact new key, then, only within that approval:

```sh
terraform -chdir=terraform/operational69 init -input=false -lockfile=readonly -backend-config=/private/approved-operational69-backend.hcl
terraform -chdir=terraform/operational69 plan -input=false -var-file=/private/approved-operational69.tfvars -out=/private/operational69.tfplan
terraform -chdir=terraform/operational69 show -no-color /private/operational69.tfplan
```

Review the full refreshed untargeted plan: only the listed new resources and standalone shared-SG rule objects may have actions. Reader desired counts remain zero. No task starts or secret population occur through Terraform. Avoid state migration, shared-state reads, targeting, disabled locking, drift suppression or importing existing names.

Resource creation, secret population, archive staging, authority materialization/adoption, cloud observation preflight, every registration/export pair, and handoff revision/start each require their own execution approval. The two secret containers use seven-day recovery and destruction protection; authorized operators later supply fresh matching token/principals values through the established secure path. A registered definition does not establish usable `AWSCURRENT` values.

Reader ingress is operator-only TCP8000; all tasks use private subnets without public IPs. EFS is TCP2049 and operator DB access is TCP5432. Existing NAT/S3 topology is retained. HTTPS egress supports AWS image/log/secret delivery and can reach external hosts; absence of model credentials is not network denial.

Terraform owns desired zero for preparation. Do not apply this preparation configuration over a separately approved active profile: reconcile the intended lifecycle/revision before a later apply. Imports, composition, candidate creation, seal/install, CAS/public activation, model sends and shared serving-wrapper changes require separate work and approval.
