# Bootstrap stack. Applied MANUALLY, ONCE per AWS account, by a human with
# admin credentials. It creates the GitHub OIDC provider and the two roles the
# pipeline assumes, then wires up the GitHub Environments and their AWS_ROLE_ARN
# secrets so the workflows can authenticate with no long-lived keys.
#
# Why a separate stack from the main one:
#   - Chicken and egg: the main pipeline needs the deploy role to exist before
#     it can run. This stack creates it.
#   - Higher privilege: creating IAM + OIDC needs admin. Keeping it in its own
#     state means the pipeline's deploy role never needs permission to edit its
#     own trust policy.
#   - Audit clarity: bootstrap changes are rare and tied to a named operator,
#     separate from the high-volume application applies.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

# Auth picks up GITHUB_TOKEN from the environment. Easiest source:
#   gh auth login --scopes repo && export GITHUB_TOKEN=$(gh auth token)
provider "github" {
  owner = var.github_org
}

locals {
  oidc_url = "https://token.actions.githubusercontent.com"

  # The OIDC "sub" claim binds a role to one repo AND one environment. This is
  # the whole security model: a role only trusts tokens minted for a specific
  # environment, so a PR (or a workflow in another repo) cannot assume it.
  deploy_subs = [
    "repo:${var.github_org}/${var.repo}:environment:sandbox",
    "repo:${var.github_org}/${var.repo}:environment:prod",
  ]
  plan_subs = [
    "repo:${var.github_org}/${var.repo}:environment:sandbox-plan",
    "repo:${var.github_org}/${var.repo}:environment:prod-plan",
  ]
}

# --- OIDC provider (one per AWS account) --------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = local.oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- Deploy role (apply) ------------------------------------------------------
# AdministratorAccess because Terraform manages the whole platform. The control
# is upstream of the role: its trust policy only accepts apply-environment
# tokens, and the prod environment is gated by a tag pattern plus a reviewer.
# For real prod, give prod its own role in its own AWS account.

data "aws_iam_policy_document" "deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.deploy_subs
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.repo}-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_assume.json
  description        = "Apply role for ${var.repo}. Assumed only from the sandbox and prod GitHub Environments."
}

resource "aws_iam_role_policy_attachment" "deploy_admin" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- Plan role (read-only) ----------------------------------------------------
# Assumed by PR plan jobs. A malicious PR that swaps `plan` for `apply` cannot
# do damage: this role is read-only, so any mutating call fails at the AWS API.
# It also needs write on the lock table so `terraform plan` can take the state
# lock during refresh.

data "aws_iam_policy_document" "plan_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_subs
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.repo}-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_assume.json
  description        = "Read-only plan role for ${var.repo}. Assumed by PR plan jobs."
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "plan_lock" {
  statement {
    sid    = "TerraformStateLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.state_lock_table}"]
  }
}

resource "aws_iam_policy" "plan_lock" {
  name   = "${var.repo}-plan-lock"
  policy = data.aws_iam_policy_document.plan_lock.json
}

resource "aws_iam_role_policy_attachment" "plan_lock" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.plan_lock.arn
}

# --- GitHub Environments + AWS_ROLE_ARN secrets -------------------------------
# Four environments, by design:
#   sandbox       apply env, main only, no reviewer        -> deploy role
#   sandbox-plan  plan env, any ref so PRs can plan         -> plan role
#   prod          apply env, tag v*.*.* + reviewer required -> deploy role
#   prod-plan     plan env, any ref                         -> plan role

locals {
  envs = {
    sandbox = {
      name             = "sandbox"
      arn              = aws_iam_role.deploy.arn
      gate             = "main"
      require_reviewer = false
    }
    sandbox_plan = {
      name             = "sandbox-plan"
      arn              = aws_iam_role.plan.arn
      gate             = "none"
      require_reviewer = false
    }
    prod = {
      name             = "prod"
      arn              = aws_iam_role.deploy.arn
      gate             = "tag"
      require_reviewer = true
    }
    prod_plan = {
      name             = "prod-plan"
      arn              = aws_iam_role.plan.arn
      gate             = "none"
      require_reviewer = false
    }
  }
}

# Look up the numeric IDs for the reviewer usernames.
data "github_user" "reviewers" {
  for_each = toset(var.reviewers)
  username = each.value
}

resource "github_repository_environment" "this" {
  for_each    = local.envs
  repository  = var.repo
  environment = each.value.name

  # Plan envs have no branch restriction so PR refs can use them.
  dynamic "deployment_branch_policy" {
    for_each = each.value.gate != "none" ? [1] : []
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }

  # Required reviewer on the prod apply env. At least one listed user approves.
  dynamic "reviewers" {
    for_each = each.value.require_reviewer && length(var.reviewers) > 0 ? [1] : []
    content {
      users = [for u in data.github_user.reviewers : u.id]
    }
  }
}

# main-only branch policy for the main and tag gated envs.
resource "github_repository_environment_deployment_policy" "main_branch" {
  for_each       = { for k, v in local.envs : k => v if v.gate != "none" }
  repository     = var.repo
  environment    = github_repository_environment.this[each.key].environment
  branch_pattern = "main"
}

# Tag policy v*.*.* on the prod apply env only. Combined with the main policy,
# prod allows "main branch OR v*.*.* tag". The workflow only fires on tags, so
# in practice prod deploys are tag-only.
resource "github_repository_environment_deployment_policy" "tag_prod" {
  for_each    = { for k, v in local.envs : k => v if v.gate == "tag" }
  repository  = var.repo
  environment = github_repository_environment.this[each.key].environment
  tag_pattern = "v*.*.*"
}

resource "github_actions_environment_secret" "aws_role_arn" {
  for_each    = local.envs
  repository  = var.repo
  environment = github_repository_environment.this[each.key].environment
  secret_name = "AWS_ROLE_ARN"
  value       = each.value.arn
}

# --- Outputs ------------------------------------------------------------------

output "oidc_provider_arn" {
  description = "OIDC provider ARN. Record in your account inventory."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "deploy_role_arn" {
  description = "Apply role ARN. Written to AWS_ROLE_ARN on the sandbox and prod environments."
  value       = aws_iam_role.deploy.arn
}

output "plan_role_arn" {
  description = "Read-only plan role ARN. Written to AWS_ROLE_ARN on the sandbox-plan and prod-plan environments."
  value       = aws_iam_role.plan.arn
}
