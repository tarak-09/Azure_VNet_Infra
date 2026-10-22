module "vnet" {
  source = "../../terraform-azurerm-virtual-network"

  resource_group_name = var.resource_group_name
  location            = var.location
  environment         = var.environment
  workload            = var.workload
  address_space       = var.address_space
  tags                = var.tags
}
