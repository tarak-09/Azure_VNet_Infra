output "hub_vnet_id" {
  value = module.hub.vnet_id
}

output "hub_subnet_ids" {
  value = module.hub.subnet_ids
}

output "spoke_vnet_id" {
  value = module.spoke.vnet_id
}

output "spoke_subnet_ids" {
  value = module.spoke.subnet_ids
}
