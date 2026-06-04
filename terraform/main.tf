provider "aws" {
  region = var.aws_region

  # Every resource in this stack gets these tags. Environment is the one that
  # changes per apply, so you can always tell sandbox state from prod state.
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = var.project
      Environment = var.environment
    }
  }
}

locals {
  name = "${var.project}-${var.environment}"
}

# ------------------------------------------------------------------------------
# Example workload.
#
# This is deliberately a null_resource: it creates nothing in AWS, so the repo
# applies cleanly in any account and costs nothing. It exists to prove the loop
# end to end: PR plan, merge to sandbox, tag to promote to prod. Swap this out
# for real modules (VPC, ECS, S3, etc.) once the pipeline is wired up.
#
# The triggers map means any change to environment/project/note shows up as a
# plan diff, so you get a real "1 to change" in CI instead of a no-op.
# ------------------------------------------------------------------------------
resource "null_resource" "hello" {
  triggers = {
    name        = local.name
    environment = var.environment
    note        = var.note
  }

  provisioner "local-exec" {
    command = "echo 'Deployed ${local.name}: ${var.note}'"
  }
}
