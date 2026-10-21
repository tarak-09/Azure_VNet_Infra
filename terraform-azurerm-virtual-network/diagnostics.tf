# Retention is not set here: Azure retired retention on diagnostic settings. Configure it on the
# Log Analytics workspace (see var.diagnostic_retention_days).

resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count = var.log_analytics_workspace_id == null ? 0 : 1

  name                       = "diag-${local.vnet_name}"
  target_resource_id         = azurerm_virtual_network.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each = var.log_analytics_workspace_id == null ? {} : local.subnets_with_nsg

  name                       = "diag-${azurerm_network_security_group.this[each.key].name}"
  target_resource_id         = azurerm_network_security_group.this[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
