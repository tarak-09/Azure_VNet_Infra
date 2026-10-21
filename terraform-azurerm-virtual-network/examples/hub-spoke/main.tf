terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81.0, < 5.0.0"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate-prod-eus"
  #   storage_account_name = "sttfstateprodeus"
  #   container_name       = "tfstate"
  #   key                  = "network/hub-spoke.tfstate"
  # }
}

# Subscription comes from `az account set` or ARM_SUBSCRIPTION_ID; nothing is hard-coded.
provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "hub" {
  name = var.hub_resource_group_name
}

data "azurerm_resource_group" "spoke" {
  name = var.spoke_resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.log_analytics_resource_group
}

locals {
  hub_bastion_prefix = "10.0.2.0/26"
  hub_shared_prefix  = "10.0.3.0/24"
  spoke_app_prefix   = "10.1.0.0/24"
  spoke_data_prefix  = "10.1.1.0/24"
}

# ---------- Hub ----------

module "hub" {
  source = "../.."

  resource_group_name = data.azurerm_resource_group.hub.name
  location            = data.azurerm_resource_group.hub.location
  environment         = var.environment
  workload            = "hub"
  address_space       = ["10.0.0.0/16"]

  ddos_protection_plan_id    = var.ddos_protection_plan_id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
  cost_center                = var.cost_center
  owner                      = var.owner

  subnets = {
    GatewaySubnet = {
      address_prefixes = ["10.0.0.0/27"]
    }

    AzureFirewallSubnet = {
      address_prefixes = ["10.0.1.0/26"]
    }

    # Rules required by Azure Bastion:
    # https://learn.microsoft.com/azure/bastion/bastion-nsg
    AzureBastionSubnet = {
      address_prefixes = [local.hub_bastion_prefix]
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
          name                         = "allow-gateway-manager-inbound"
          priority                     = 130
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["443"]
          source_address_prefixes      = ["GatewayManager"]
          destination_address_prefixes = ["*"]
        },
        {
          name                         = "allow-azure-load-balancer-inbound"
          priority                     = 140
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["443"]
          source_address_prefixes      = ["AzureLoadBalancer"]
          destination_address_prefixes = ["*"]
        },
        {
          name                         = "allow-bastion-host-communication-inbound"
          priority                     = 150
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["8080", "5701"]
          source_address_prefixes      = ["VirtualNetwork"]
          destination_address_prefixes = ["VirtualNetwork"]
        },
        {
          name                         = "allow-ssh-rdp-outbound"
          priority                     = 100
          direction                    = "Outbound"
          access                       = "Allow"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["22", "3389"]
          source_address_prefixes      = ["*"]
          destination_address_prefixes = ["VirtualNetwork"]
        },
        {
          name                         = "allow-azure-cloud-outbound"
          priority                     = 110
          direction                    = "Outbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["443"]
          source_address_prefixes      = ["*"]
          destination_address_prefixes = ["AzureCloud"]
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
        {
          name                         = "allow-get-session-information-outbound"
          priority                     = 130
          direction                    = "Outbound"
          access                       = "Allow"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["80"]
          source_address_prefixes      = ["*"]
          destination_address_prefixes = ["Internet"]
        },
      ]
    }

    shared = {
      address_prefixes  = [local.hub_shared_prefix]
      service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]
    }
  }
}

# ---------- Spoke ----------

module "spoke" {
  source = "../.."

  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
  environment         = var.environment
  workload            = "app"
  address_space       = ["10.1.0.0/16"]

  ddos_protection_plan_id    = var.ddos_protection_plan_id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
  cost_center                = var.cost_center
  owner                      = var.owner

  subnets = {
    app = {
      address_prefixes = [local.spoke_app_prefix]
      nsg_rules = [
        {
          name                         = "allow-https-from-hub-inbound"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["443"]
          source_address_prefixes      = [local.hub_shared_prefix]
          destination_address_prefixes = [local.spoke_app_prefix]
        },
        {
          name                         = "allow-ssh-rdp-from-bastion-inbound"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["22", "3389"]
          source_address_prefixes      = [local.hub_bastion_prefix]
          destination_address_prefixes = [local.spoke_app_prefix]
        },
        {
          name                         = "deny-vnet-inbound"
          priority                     = 4000
          direction                    = "Inbound"
          access                       = "Deny"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["*"]
          source_address_prefixes      = ["VirtualNetwork"]
          destination_address_prefixes = ["*"]
        },
      ]
    }

    data = {
      address_prefixes  = [local.spoke_data_prefix]
      service_endpoints = ["Microsoft.Sql"]
      nsg_rules = [
        {
          name                         = "allow-sql-from-app-inbound"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["1433"]
          source_address_prefixes      = [local.spoke_app_prefix]
          destination_address_prefixes = [local.spoke_data_prefix]
        },
        {
          name                         = "allow-ssh-rdp-from-bastion-inbound"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["22", "3389"]
          source_address_prefixes      = [local.hub_bastion_prefix]
          destination_address_prefixes = [local.spoke_data_prefix]
        },
        {
          name                         = "deny-vnet-inbound"
          priority                     = 4000
          direction                    = "Inbound"
          access                       = "Deny"
          protocol                     = "*"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["*"]
          source_address_prefixes      = ["VirtualNetwork"]
          destination_address_prefixes = ["*"]
        },
      ]
    }
  }
}

# ---------- Peering ----------

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-${module.hub.vnet_name}-to-${module.spoke.vnet_name}"
  resource_group_name       = data.azurerm_resource_group.hub.name
  virtual_network_name      = module.hub.vnet_name
  remote_virtual_network_id = module.spoke.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${module.spoke.vnet_name}-to-${module.hub.vnet_name}"
  resource_group_name       = data.azurerm_resource_group.spoke.name
  virtual_network_name      = module.spoke.vnet_name
  remote_virtual_network_id = module.hub.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false

  # true only once a VPN/ExpressRoute gateway exists in the hub's GatewaySubnet.
  use_remote_gateways = var.use_remote_gateway

  # The hub side must offer gateway transit before the spoke can use it.
  depends_on = [azurerm_virtual_network_peering.hub_to_spoke]
}
