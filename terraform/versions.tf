terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Local backend: state lives on disk under ./state/<env>.tfstate. The path is
  # supplied per env at init time so each env keeps its own state file:
  #   terraform init -backend-config=backends/<env>.hcl
  # Local state is simple and great for learning or a solo demo. For a real
  # team, switch this to `backend "s3" {}` so state is shared and locked.
  backend "local" {}
}
