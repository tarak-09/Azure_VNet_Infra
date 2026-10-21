# ---------- Placement ----------

variable "resource_group_name" {
  description = "Existing resource group the VNet, subnets and NSGs are created in."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. eastus. Also drives the short region code in resource names."
  type        = string
}

# ---------- Naming ----------

variable "environment" {
  description = "Deployment environment. Used in resource names and the environment tag."
  type        = string

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, staging, prod."
  }
}

variable "workload" {
  description = "Short workload name used in resource names, e.g. hub, payments. Lowercase letters, digits and hyphens, 2-20 chars."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.workload))
    error_message = "workload must match ^[a-z0-9-]{2,20}$."
  }
}

# ---------- Network ----------

variable "address_space" {
  description = "VNet address space as CIDRs."
  type        = list(string)

  validation {
    condition     = length(var.address_space) >= 1
    error_message = "address_space must contain at least one CIDR."
  }

  validation {
    condition     = alltrue([for c in var.address_space : can(cidrhost(c, 0))])
    error_message = "Every address_space entry must be a valid CIDR, e.g. 10.0.0.0/16."
  }
}

variable "subnets" {
  description = <<-EOT
    Subnets keyed by short name. The key becomes snet-<key>-<workload>-<env>-<region>, except
    Azure-reserved names (GatewaySubnet, AzureFirewallSubnet, AzureFirewallManagementSubnet,
    AzureBastionSubnet, RouteServerSubnet), which are used as-is because Azure requires them.

    A subnet with nsg_rules gets its own NSG. Each rule takes lists for ports and addresses; a
    single-element list is sent to Azure as the singular attribute, so "*" and service tags
    (Internet, VirtualNetwork, GatewayManager, ...) work as one-element lists. Lists with more than
    one element must contain only port numbers/ranges or IP addresses/CIDRs.

    delegation.name is the service to delegate to (e.g. Microsoft.Web/serverFarms) and
    delegation.service_actions the actions it is granted.
  EOT
  type = map(object({
    address_prefixes                               = list(string)
    service_endpoints                              = optional(list(string), [])
    private_link_endpoint_network_policies_enabled = optional(bool, false)
    private_link_service_network_policies_enabled  = optional(bool, false)
    delegation = optional(object({
      name            = string
      service_actions = list(string)
    }))
    nsg_rules = optional(list(object({
      name                         = string
      priority                     = number
      direction                    = string
      access                       = string
      protocol                     = string
      source_port_ranges           = list(string)
      destination_port_ranges      = list(string)
      source_address_prefixes      = list(string)
      destination_address_prefixes = list(string)
    })), [])
  }))
  default = {}

  validation {
    condition     = alltrue(flatten([for s in var.subnets : [for p in s.address_prefixes : can(cidrhost(p, 0))]]))
    error_message = "Every subnet address_prefixes entry must be a valid CIDR."
  }

  validation {
    condition = alltrue([
      for k, s in var.subnets : !(contains(["GatewaySubnet", "AzureFirewallSubnet", "AzureFirewallManagementSubnet", "RouteServerSubnet"], k) && length(s.nsg_rules) > 0)
    ])
    error_message = "GatewaySubnet, AzureFirewallSubnet, AzureFirewallManagementSubnet and RouteServerSubnet do not support NSGs; remove their nsg_rules."
  }

  validation {
    condition     = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules : can(regex("^[a-z0-9][a-z0-9-]{0,78}[a-z0-9]$", r.name))]]))
    error_message = "NSG rule names must be lowercase kebab-case, 2-80 chars."
  }

  validation {
    condition     = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules : r.priority >= 100 && r.priority <= 4096]]))
    error_message = "NSG rule priority must be between 100 and 4096."
  }

  validation {
    condition = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules :
      contains(["Inbound", "Outbound"], r.direction) &&
      contains(["Allow", "Deny"], r.access) &&
      contains(["Tcp", "Udp", "Icmp", "Esp", "Ah", "*"], r.protocol)
    ]]))
    error_message = "NSG rule direction must be Inbound|Outbound, access Allow|Deny, protocol Tcp|Udp|Icmp|Esp|Ah|*."
  }

  validation {
    condition = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules : [
      for l in [r.source_port_ranges, r.destination_port_ranges, r.source_address_prefixes, r.destination_address_prefixes] : length(l) >= 1
    ]]]))
    error_message = "NSG rule port and address lists must each have at least one element (use [\"*\"] for any)."
  }

  validation {
    condition = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules : [
      for l in [r.source_port_ranges, r.destination_port_ranges] : length(l) == 1 || alltrue([for p in l : can(regex("^[0-9]+(-[0-9]+)?$", p))])
    ]]]))
    error_message = "Multi-element port lists may only contain ports or ranges (e.g. 80, 8080-8090), not \"*\"."
  }

  validation {
    condition = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules : [
      for l in [r.source_address_prefixes, r.destination_address_prefixes] : length(l) == 1 || alltrue([for a in l : can(cidrhost(a, 0)) || can(cidrhost("${a}/32", 0))])
    ]]]))
    error_message = "Multi-element address lists may only contain IPs or CIDRs. Use a one-element list for \"*\" or a service tag."
  }
}

variable "dns_servers" {
  description = "Custom DNS server IPs. Empty uses Azure-provided DNS."
  type        = list(string)
  default     = []
}

variable "ddos_protection_plan_id" {
  description = "Resource ID of a DDoS Network Protection plan to attach, or null for none."
  type        = string
  default     = null
}

# ---------- Diagnostics ----------

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for VNet metrics and NSG logs. null disables diagnostics."
  type        = string
  default     = null
}

variable "diagnostic_retention_days" {
  description = <<-EOT
    Intended log retention in days. NOT applied by this module: Azure retired per-diagnostic-setting
    retention (azurerm 4.x deprecates retention_policy). Set retention on the Log Analytics workspace
    or per table instead. Kept so callers have one place to declare the requirement.
  EOT
  type        = number
  default     = 90

  validation {
    condition     = var.diagnostic_retention_days >= 7 && var.diagnostic_retention_days <= 730
    error_message = "diagnostic_retention_days must be between 7 and 730."
  }
}

# ---------- Tags ----------

variable "tags" {
  description = "Extra tags. Merged over the mandatory tags, so a key here overrides the module's value."
  type        = map(string)
  default     = {}
}

variable "cost_center" {
  description = "Cost center tag value."
  type        = string

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "owner" {
  description = "Owner tag value (team or person accountable for the VNet)."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "data_classification" {
  description = "Data classification tag value."
  type        = string
  default     = "Internal"

  validation {
    condition     = contains(["Public", "Internal", "Confidential", "Restricted"], var.data_classification)
    error_message = "data_classification must be one of: Public, Internal, Confidential, Restricted."
  }
}
