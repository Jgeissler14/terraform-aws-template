
# terraform-null-label example used here: Output list of tags applied in each format
output "tags_as_list_of_maps" {
  value = module.this.tags_as_list_of_maps
}

output "tags" {
  value = module.this.tags
}

output "id" {
  value = module.this.id
}
