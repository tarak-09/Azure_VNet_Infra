data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

module "network" {
  source = "../../terraform-azurerm-virtual-network"

  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  environment         = var.environment
  workload            = var.workload
  address_space       = var.address_space
  cost_center         = var.cost_center
  owner               = var.owner

  subnets = {
    # The NSG default rules already deny Internet inbound; the explicit rule documents the intent
    # and gives the subnet an NSG (the module only creates one when there are rules).
    app = {
      address_prefixes = [var.app_subnet_prefix]
      nsg_rules = [
        {
          name                         = "deny-internet-inbound"
          priority                     = 4096
          direction                    = "Inbound"
          access                       = "Deny"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["*"]
          source_address_prefixes      = ["Internet"]
          destination_address_prefixes = ["*"]
        },
      ]
    }
  }
}
