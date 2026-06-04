output "name" {
  description = "Composed name for this env's deployment."
  value       = local.name
}

output "environment" {
  description = "The environment this state was applied with."
  value       = var.environment
}

output "note" {
  description = "The note baked into the example resource. Change var.note to see a plan diff."
  value       = var.note
}
