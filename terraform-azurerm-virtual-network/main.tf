resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = local.tags

  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_plan_id == null ? [] : [var.ddos_protection_plan_id]

    content {
      id     = ddos_protection_plan.value
      enable = true
    }
  }
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = local.subnet_names[each.key]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints

  private_endpoint_network_policies             = each.value.private_link_endpoint_network_policies_enabled ? "Enabled" : "Disabled"
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]

    content {
      name = lower(replace(replace(delegation.value.name, "/", "-"), ".", "-"))

      service_delegation {
        name    = delegation.value.name
        actions = delegation.value.service_actions
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.subnets_with_nsg

  name                = "${local.nsg_prefix}-${lower(each.key)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}

# Azure rejects "*" and service tags in the plural *_ranges / *_prefixes attributes, so a
# one-element list is sent as the singular attribute and longer lists as the plural one.
resource "azurerm_network_security_rule" "this" {
  for_each = { for r in local.nsg_rules_flat : "${r.subnet_name}-${r.name}" => r }

  name                        = each.value.name
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.value.subnet_name].name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol

  source_port_range  = length(each.value.source_port_ranges) == 1 ? each.value.source_port_ranges[0] : null
  source_port_ranges = length(each.value.source_port_ranges) > 1 ? each.value.source_port_ranges : null

  destination_port_range  = length(each.value.destination_port_ranges) == 1 ? each.value.destination_port_ranges[0] : null
  destination_port_ranges = length(each.value.destination_port_ranges) > 1 ? each.value.destination_port_ranges : null

  source_address_prefix   = length(each.value.source_address_prefixes) == 1 ? each.value.source_address_prefixes[0] : null
  source_address_prefixes = length(each.value.source_address_prefixes) > 1 ? each.value.source_address_prefixes : null

  destination_address_prefix   = length(each.value.destination_address_prefixes) == 1 ? each.value.destination_address_prefixes[0] : null
  destination_address_prefixes = length(each.value.destination_address_prefixes) > 1 ? each.value.destination_address_prefixes : null
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnets_with_nsg

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id

  # Associate only after all rules exist, so the subnet never sits behind an NSG that is
  # still missing allow rules (Bastion, for one, fails to deploy in that window).
  depends_on = [azurerm_network_security_rule.this]
}
