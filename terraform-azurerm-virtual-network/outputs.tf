output "vnet_id" {
  description = "VNet resource ID."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "VNet name."
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "VNet address space."
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "Subnet IDs keyed by the subnets map key."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "subnet_address_prefixes" {
  description = "Subnet address prefixes keyed by the subnets map key."
  value       = { for k, s in azurerm_subnet.this : k => s.address_prefixes }
}

output "nsg_ids" {
  description = "NSG IDs keyed by subnet key (only subnets with nsg_rules)."
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
}

output "tags" {
  description = "Tags applied to taggable resources."
  value       = local.tags
}
