terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9"
    }
  }
  backend "s3" {
    bucket = "" 
    key    = ""
    region = ""
  }
}


provider "aws" {
  region = var.region
}