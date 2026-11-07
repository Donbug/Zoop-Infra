variable "expected_account_id" {
  type        = string
  description = "Approved deployment account; provider rejects other accounts."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "Supply a twelve-digit approved account ID."
  }
}

variable "aws_region" {
  type = string
  validation {
    condition     = var.aws_region == "ap-northeast-2"
    error_message = "This fixed dev root is for ap-northeast-2."
  }
}

variable "existing" {
  description = "Exact approved shared-resource identities, read as metadata only."
  type = object({
    vpc_id             = string
    private_subnet_ids = set(string)
    cluster_arn        = string
    namespace_id       = string
    efs_id             = string
    efs_security_group = string
    rds_security_group = string
    access_points = object({
      archive    = string
      authority  = string
      operations = string
      artifacts  = string
    })
  })
  validation {
    condition = (
      length(var.existing.private_subnet_ids) == 2 &&
      can(regex("^vpc-[0-9a-f]+$", var.existing.vpc_id)) &&
      can(regex("^fs-[0-9a-f]+$", var.existing.efs_id)) &&
      can(regex("^ns-[a-z0-9]+$", var.existing.namespace_id)) &&
      alltrue([for id in var.existing.private_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))]) &&
      alltrue([for id in values(var.existing.access_points) : can(regex("^fsap-[0-9a-f]+$", id))]) &&
      length(toset(values(var.existing.access_points))) == 4 &&
      alltrue([for id in [var.existing.efs_security_group, var.existing.rds_security_group] : can(regex("^sg-[0-9a-f]+$", id))]) &&
      can(regex("^arn:aws:ecs:ap-northeast-2:[0-9]{12}:cluster/zoop-dev$", var.existing.cluster_arn))
    )
    error_message = "Supply exact distinct AP IDs, two subnet IDs and the existing dev infrastructure IDs."
  }
}

variable "images" {
  description = "Reviewed full ECR digest pins and matching repository metadata ARNs."
  type = object({
    reader   = object({ pin = string, repository_arn = string })
    operator = object({ pin = string, repository_arn = string })
  })
  validation {
    condition = alltrue([for image in [var.images.reader, var.images.operator] :
      can(regex("^[0-9]{12}\\.dkr\\.ecr\\.ap-northeast-2\\.amazonaws\\.com/[a-z0-9_./-]+@sha256:[0-9a-f]{64}$", image.pin)) &&
      can(regex("^arn:aws:ecr:ap-northeast-2:[0-9]{12}:repository/[a-z0-9_./-]+$", image.repository_arn)) &&
      try(split("@", image.pin)[0] == "${split(":", image.repository_arn)[4]}.dkr.ecr.ap-northeast-2.amazonaws.com/${split("repository/", image.repository_arn)[1]}", false)
    ])
    error_message = "Use full repository@sha256 pins with matching ECR repository ARNs."
  }
}

variable "reader_python" {
  type        = string
  description = "Exact approved installed interpreter path; expected /opt/zoop/service/.venv/bin/python, subject to image preflight."
  validation {
    condition     = can(regex("^/opt/zoop/(service|pipeline)/\\.venv/bin/python(3(\\.[0-9]+)?)?$", var.reader_python))
    error_message = "Supply the reviewed installed virtualenv Python executable."
  }
}

variable "database" {
  type = object({
    address         = string
    name            = string
    credentials_arn = string
    csrf_secret_arn = string
    csrf_key_id     = string
    kms_key_arns    = set(string)
  })
  description = "RDS endpoint/database and existing DB/CSRF secret metadata; optional exact customer-managed decrypt keys."
  validation {
    condition = (
      can(regex("^[a-zA-Z0-9.-]+\\.rds\\.amazonaws\\.com$", var.database.address)) &&
      can(regex("^[a-zA-Z0-9_]+$", var.database.name)) && length(var.database.csrf_key_id) > 0 &&
      alltrue([for arn in [var.database.credentials_arn, var.database.csrf_secret_arn] : can(regex("^arn:aws:secretsmanager:ap-northeast-2:[0-9]{12}:secret:.+$", arn))]) &&
      alltrue([for arn in var.database.kms_key_arns : can(regex("^arn:aws:kms:ap-northeast-2:[0-9]{12}:key/[a-z0-9-]+$", arn))])
    )
    error_message = "Supply actual endpoint, database name and secret/key ARNs, not secret values."
  }
}

variable "archive" {
  type = object({
    source_path     = string
    sha256          = string
    manifest_path   = string
    manifest_sha256 = string
  })
  description = "Staged source tar and external MANIFEST on the existing operations AP; both trusted hashes are required."
  validation {
    condition = (
      alltrue([for p in [var.archive.source_path, var.archive.manifest_path] : startswith(p, "/mnt/zoop-ops/") && !can(regex("(^|/)\\.\\.?(/|$)|//", p))]) &&
      alltrue([for h in [var.archive.sha256, var.archive.manifest_sha256] : can(regex("^[0-9a-f]{64}$", h))])
    )
    error_message = "Source and manifest must be normalized operations mount paths with trusted SHA-256 pins."
  }
}

variable "authority" {
  type = object({
    inventory_path   = string
    inventory_sha256 = string
    deny_all_grants  = string
    operator_sources = string
    principal        = string
  })
  description = "Reviewed materialized current authority paths and principal reference (not the token)."
  validation {
    condition = (
      alltrue([for p in [var.authority.inventory_path, var.authority.deny_all_grants, var.authority.operator_sources] : startswith(p, "/mnt/zoop-op69-authority/") && !can(regex("(^|/)\\.\\.?(/|$)|//", p))]) &&
      can(regex("^[0-9a-f]{64}$", var.authority.inventory_sha256)) &&
      can(regex("^[a-zA-Z0-9:_-]+$", var.authority.principal))
    )
    error_message = "Supply normalized independent authority paths, inventory SHA and exact principal."
  }
}

variable "profiles" {
  type = map(object({
    registration_request = string
    registration_result  = string
    bindings_selection   = string
    bindings_output      = string
    bindings_result      = string
    handoff = optional(object({
      root                   = string
      canonical              = string
      decisions              = string
      frozen_bindings        = string
      frozen_bindings_sha256 = string
      exports                = string
      handoff_id             = string
      manifest_digest        = string
      bundle_digest          = string
      target_bindings        = string
      selected_rows_sha256   = string
    }))
  }))
  description = "Four exact profile control paths; handoff is a later complete reviewed revision after selected-row equality."
  validation {
    condition = (
      toset(keys(var.profiles)) == toset(["existing2", "six", "three", "eu11"]) &&
      alltrue([for name, p in var.profiles :
        alltrue([for path in [p.registration_request, p.registration_result, p.bindings_selection, p.bindings_output, p.bindings_result] : startswith(path, "/mnt/zoop-op69-control/${name}/") && !can(regex("(^|/)\\.\\.?(/|$)|//", path))]) &&
        length(toset([p.registration_request, p.registration_result, p.bindings_selection, p.bindings_output, p.bindings_result])) == 5 &&
        (p.handoff == null ? true : (
          alltrue([for path in [p.handoff.root, p.handoff.canonical, p.handoff.decisions, p.handoff.frozen_bindings, p.handoff.exports, p.handoff.target_bindings] :
          (startswith(path, "/srv/zoop-op69/archive/operational69-20261103-v1/payload/") || startswith(path, "/mnt/zoop-op69-control/${name}/")) && !can(regex("(^|/)\\.\\.?(/|$)|//", path))]) &&
          alltrue([for h in [p.handoff.frozen_bindings_sha256, p.handoff.manifest_digest, p.handoff.bundle_digest, p.handoff.selected_rows_sha256] : can(regex("^[0-9a-f]{64}$", h))]) &&
          length(p.handoff.handoff_id) > 0 && p.handoff.target_bindings == p.bindings_output
        ))
      ])
    )
    error_message = "Supply exactly four profiles with distinct normalized request/result/selection/output paths and complete handoff pins."
  }
}
