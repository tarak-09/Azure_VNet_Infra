locals {
  # Every name ends with this, e.g. vnet-core-dev-centralus.
  name_suffix = "${var.workload}-${var.environment}-${var.location}"

  tags = merge({
    environment = var.environment
    workload    = var.workload
    managed_by  = "terraform"
  }, var.tags)
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = local.tags

  # Encrypts VM-to-VM traffic for VM sizes that support it (D/E v4+ etc. with Accelerated
  # Networking). AllowUnencrypted is the only mode Azure supports today: VMs that can't
  # encrypt still communicate, just unencrypted. Free.
  encryption {
    enforcement = "AllowUnencrypted"
  }
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "snet-${each.key}-${local.name_suffix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.address_prefix]
}

# One NSG per subnet. Azure's built-in rules already allow traffic inside the VNet and block
# inbound traffic from the internet; nsg_rules are added on top of those.
resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "nsg-${each.key}-${local.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags

  dynamic "security_rule" {
    for_each = each.value.nsg_rules

    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_address_prefix      = security_rule.value.source_address
      source_port_range          = "*"
      destination_address_prefix = security_rule.value.destination_address
      destination_port_range     = security_rule.value.destination_port
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
