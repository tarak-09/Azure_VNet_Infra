output "vnet_id" {
  description = "VNet resource ID."
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "VNet name."
  value       = module.network.vnet_name
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value       = module.network.subnet_ids
}
