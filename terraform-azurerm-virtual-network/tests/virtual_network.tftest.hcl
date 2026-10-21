# Offline tests: the azurerm provider is mocked, so nothing is created and no login is needed.
# Run with: terraform init && terraform test

mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-test"
  location            = "East US"
  environment         = "dev"
  workload            = "hub"
  address_space       = ["10.0.0.0/16"]
  cost_center         = "cc-1234"
  owner               = "platform-team"

  subnets = {
    GatewaySubnet = {
      address_prefixes = ["10.0.0.0/27"]
    }
    AzureBastionSubnet = {
      address_prefixes = ["10.0.2.0/26"]
      nsg_rules = [
        {
          name                         = "allow-https-inbound"
          priority                     = 120
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["443"]
          source_address_prefixes      = ["Internet"]
          destination_address_prefixes = ["*"]
        },
        {
          name                         = "allow-bastion-communication-outbound"
          priority                     = 120
          direction                    = "Outbound"
          access                       = "Allow"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["8080", "5701"]
          source_address_prefixes      = ["VirtualNetwork"]
          destination_address_prefixes = ["VirtualNetwork"]
        },
      ]
    }
    app = {
      address_prefixes = ["10.0.3.0/24"]
      delegation = {
        name            = "Microsoft.Web/serverFarms"
        service_actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
      nsg_rules = [
        {
          name                         = "allow-web-from-two-ranges"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["80", "443"]
          source_address_prefixes      = ["10.1.0.0/24", "10.2.0.0/24"]
          destination_address_prefixes = ["10.0.3.0/24"]
        },
      ]
    }
  }
}

run "naming_follows_caf_and_keeps_reserved_subnet_names" {
  command = plan

  assert {
    condition     = azurerm_virtual_network.this.name == "vnet-hub-dev-eus"
    error_message = "VNet name should be vnet-<workload>-<env>-<region>."
  }

  assert {
    condition     = azurerm_subnet.this["app"].name == "snet-app-hub-dev-eus"
    error_message = "Regular subnets should be snet-<key>-<name_base>."
  }

  assert {
    condition     = azurerm_subnet.this["GatewaySubnet"].name == "GatewaySubnet" && azurerm_subnet.this["AzureBastionSubnet"].name == "AzureBastionSubnet"
    error_message = "Azure-reserved subnet names must be kept exactly."
  }

  assert {
    condition     = azurerm_network_security_group.this["AzureBastionSubnet"].name == "nsg-hub-dev-eus-azurebastionsubnet"
    error_message = "NSG name should be nsg-<name_base>-<lowercased subnet key>."
  }

  assert {
    condition     = azurerm_subnet.this["app"].delegation[0].service_delegation[0].name == "Microsoft.Web/serverFarms"
    error_message = "Delegation should target the requested service."
  }
}

run "nsgs_only_for_subnets_with_rules" {
  command = plan

  assert {
    condition     = length(azurerm_network_security_group.this) == 2 && !contains(keys(azurerm_network_security_group.this), "GatewaySubnet")
    error_message = "Only subnets with nsg_rules should get an NSG."
  }

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == 2
    error_message = "Each NSG should be associated with its subnet."
  }
}

run "single_values_use_singular_attributes" {
  command = plan

  assert {
    condition = (
      azurerm_network_security_rule.this["AzureBastionSubnet-allow-https-inbound"].source_address_prefix == "Internet" &&
      azurerm_network_security_rule.this["AzureBastionSubnet-allow-https-inbound"].source_port_range == "*" &&
      azurerm_network_security_rule.this["AzureBastionSubnet-allow-https-inbound"].destination_port_range == "443"
    )
    error_message = "One-element lists should map to the singular attribute (needed for * and service tags)."
  }

  assert {
    condition = (
      toset(azurerm_network_security_rule.this["app-allow-web-from-two-ranges"].source_address_prefixes) == toset(["10.1.0.0/24", "10.2.0.0/24"]) &&
      toset(azurerm_network_security_rule.this["app-allow-web-from-two-ranges"].destination_port_ranges) == toset(["80", "443"])
    )
    error_message = "Multi-element lists should map to the plural attribute."
  }
}

run "mandatory_tags_with_caller_override" {
  command = plan

  variables {
    tags = {
      owner   = "network-team"
      project = "landing-zone"
    }
  }

  assert {
    condition     = azurerm_virtual_network.this.tags["owner"] == "network-team" && azurerm_virtual_network.this.tags["project"] == "landing-zone"
    error_message = "Caller tags should be merged and win on conflicts."
  }

  assert {
    condition = (
      azurerm_virtual_network.this.tags["managed_by"] == "terraform" &&
      azurerm_virtual_network.this.tags["module"] == "terraform-azurerm-virtual-network" &&
      azurerm_virtual_network.this.tags["data_classification"] == "Internal"
    )
    error_message = "Mandatory tags should be present."
  }
}

run "no_diagnostics_without_workspace" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.vnet) == 0 && length(azurerm_monitor_diagnostic_setting.nsg) == 0
    error_message = "No diagnostic settings when log_analytics_workspace_id is null."
  }
}

run "diagnostics_with_workspace" {
  command = plan

  variables {
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mgmt/providers/Microsoft.OperationalInsights/workspaces/log-test"
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.vnet) == 1 && length(azurerm_monitor_diagnostic_setting.nsg) == 2
    error_message = "One VNet setting plus one per NSG when a workspace is given."
  }
}

run "unknown_region_falls_back_to_substr" {
  command = plan

  variables {
    location = "polandcentral"
  }

  assert {
    condition     = azurerm_virtual_network.this.name == "vnet-hub-dev-pola"
    error_message = "Unknown regions should use the first 4 characters."
  }
}

run "rejects_bad_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_bad_workload" {
  command = plan

  variables {
    workload = "Hub_Network"
  }

  expect_failures = [var.workload]
}

run "rejects_nsg_on_gateway_subnet" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = {
        address_prefixes = ["10.0.0.0/27"]
        nsg_rules = [{
          name                         = "deny-all"
          priority                     = 4096
          direction                    = "Inbound"
          access                       = "Deny"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["*"]
          source_address_prefixes      = ["*"]
          destination_address_prefixes = ["*"]
        }]
      }
    }
  }

  expect_failures = [var.subnets]
}

run "rejects_service_tag_in_multi_value_list" {
  command = plan

  variables {
    subnets = {
      app = {
        address_prefixes = ["10.0.3.0/24"]
        nsg_rules = [{
          name                         = "bad-mixed-sources"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["443"]
          source_address_prefixes      = ["Internet", "10.1.0.0/24"]
          destination_address_prefixes = ["*"]
        }]
      }
    }
  }

  expect_failures = [var.subnets]
}

run "rejects_retention_out_of_range" {
  command = plan

  variables {
    diagnostic_retention_days = 3
  }

  expect_failures = [var.diagnostic_retention_days]
}
