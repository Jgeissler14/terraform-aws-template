variable "aws_region" {
  type        = string
  description = "AWS region for the OIDC provider and roles."
  default     = "us-east-1"
}

variable "github_org" {
  type        = string
  description = "GitHub org or user that owns the repo this account will trust."
}

variable "repo" {
  type        = string
  description = "Repository name (without the org) that GitHub Actions runs in."
}

variable "state_lock_table" {
  type        = string
  description = "DynamoDB lock table name. The read-only plan role gets write access to this so plan can acquire the state lock."
  default     = "demo-platform-terraform-locks"
}

variable "reviewers" {
  type        = list(string)
  description = "GitHub usernames allowed to approve a prod (tag) deploy. At least one is required to release."
  default     = []
}
