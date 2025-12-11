

provider "aws" {
  region = var.aws_region
}

module "storage_bucket" {
  source  = "cloudposse/s3-bucket/aws"
  version = "4.10.0"

  namespace = module.this.namespace
  stage     = module.this.stage 
  name      = "01" # optional suffix for name collision avoidance
  tenant    = module.this.tenant

  context = module.this.context
}

# ------------------------------------------------------------------------------
# Autoscaling Group Example
#
# This is an example of how to use the cloudposse/label/null module directly
# to generate a consistent name and tags for related AWS resources.
# ------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

module "asg_label" {
  source = "cloudposse/label/null"

  context = module.this.context
}

resource "aws_launch_configuration" "example" {
  # The `id` output from the label module provides the standardized resource name prefix.
  name_prefix   = module.asg_label.id
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  # The `id` output from the label module provides the standardized resource name.
  name = module.asg_label.id
  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 0 # Set to 0 to avoid running instances by default
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_configuration      = aws_launch_configuration.example.id
  vpc_zone_identifier       = [] # NOTE: This needs to be populated with subnet IDs for a real deployment

  # The `tags` output provides the full map of standardized tags.
  dynamic "tag" {
    for_each = module.this.tags_as_list_of_maps
    content {
      key                 = tag.value.key
      propagate_at_launch = tag.value.propagate_at_launch
      value               = tag.value.value
    }
  }
}

