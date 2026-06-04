variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Which environment this apply targets. Drives the Environment tag and the null_resource trigger so each env shows an independent plan."

  validation {
    condition     = contains(["sandbox", "prod"], var.environment)
    error_message = "environment must be one of: sandbox, prod. Add more in this validation as the repo grows."
  }
}

variable "project" {
  type        = string
  description = "Short project name used in resource naming and tags."
  default     = "demo-platform"
}

variable "note" {
  type        = string
  description = "Free-text note baked into the null_resource so you can see a plan diff when you change it. Stand-in for real workload config."
  default     = "hello from terraform"
}
