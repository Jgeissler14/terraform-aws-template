namespace = "es"
stage     = "dev"
name      = "app"
tenant    = "internal"

tags = {
  BusinessUnit = "finance"
  ManagedBy    = "terraform"
}

additional_tag_map = {
  propagate_at_launch = "true"
}
