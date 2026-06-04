terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Local backend: bootstrap state lives at ./state/bootstrap.tfstate.
  #   terraform init -backend-config=backends/bootstrap.hcl
  # For a shared team setup, switch to `backend "s3" {}`.
  backend "local" {}
}
