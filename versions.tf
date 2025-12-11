
terraform {
  required_version = ">= 0.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    }
  }

  backend "s3" {
    bucket = "matrix-app-tfstate"
    key    = "environments/dev/terraform.tfstate"
    region = "us-east-1"
  }
}