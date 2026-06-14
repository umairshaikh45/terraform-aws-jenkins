# Root Terragrunt configuration — inherited by all child modules via find_in_parent_folders()
#
# First-time setup — run once to create the S3 bucket automatically:
#
#   cd live/prod/jenkins
#   terragrunt init --backend-bootstrap
#
# After the bucket exists, use the normal commands:
#
#   terragrunt init
#   terragrunt plan
#   terragrunt apply

locals {
  aws_region = "us-east-1"
  project    = "jenkins"

  # -----------------------------------------------------------------------
  # Bucket name
  # -----------------------------------------------------------------------
  # Option 1 — leave empty: Terragrunt uses "terraform-state-<account-id>-<region>"
  # Option 2 — set a name:  Terragrunt creates (or reuses) that specific bucket
  custom_bucket_name = ""

  bucket_name = (
    local.custom_bucket_name != ""
    ? local.custom_bucket_name
    : "terraform-state-${get_aws_account_id()}-${local.aws_region}"
  )
}

# ---------------------------------------------------------------------------
# Remote state — S3 with native locking (no DynamoDB required)
# ---------------------------------------------------------------------------
# Terragrunt auto-creates the bucket on first `terragrunt init` (versioning,
# AES-256 SSE, and public-access blocking are enabled automatically).
#
# State path: s3://<bucket>/live/prod/jenkins/terraform.tfstate
# Locking:    S3 conditional writes (Terraform >= 1.10) — no DynamoDB needed.

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = local.bucket_name
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true # S3-native locking — requires Terraform >= 1.10
  }
}

# ---------------------------------------------------------------------------
# AWS provider — injected alongside the module files at plan/apply time
# ---------------------------------------------------------------------------
generate "aws_provider" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = {
          ManagedBy = "Terragrunt"
          Project   = "${local.project}"
        }
      }
    }
  EOF
}
