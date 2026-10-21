locals {
  # ---------- Naming (CAF: <type>-<workload>-<env>-<region>) ----------

  location_short = {
    eastus             = "eus"
    eastus2            = "eus2"
    centralus          = "cus"
    northcentralus     = "ncus"
    southcentralus     = "scus"
    westcentralus      = "wcus"
    westus             = "wus"
    westus2            = "wus2"
    westus3            = "wus3"
    canadacentral      = "cac"
    canadaeast         = "cae"
    brazilsouth        = "brs"
    northeurope        = "neu"
    westeurope         = "weu"
    uksouth            = "uks"
    ukwest             = "ukw"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    swedencentral      = "sdc"
    switzerlandnorth   = "szn"
    norwayeast         = "nwe"
    australiaeast      = "aue"
    australiasoutheast = "ause"
    southeastasia      = "sea"
    eastasia           = "ea"
    japaneast          = "jpe"
    koreacentral       = "krc"
    centralindia       = "inc"
    uaenorth           = "uan"
    southafricanorth   = "san"
  }

  # Accepts "eastus" or "East US".
  location_key = lower(replace(var.location, " ", ""))
  loc_abbr     = lookup(local.location_short, local.location_key, substr(local.location_key, 0, 4))

  name_base  = "${var.workload}-${var.environment}-${local.loc_abbr}"
  vnet_name  = "vnet-${local.name_base}"
  nsg_prefix = "nsg-${local.name_base}"

  # Azure only recognises these subnets by their exact name.
  reserved_subnet_names = ["GatewaySubnet", "AzureFirewallSubnet", "AzureFirewallManagementSubnet", "AzureBastionSubnet", "RouteServerSubnet"]

  subnet_names = {
    for k, _ in var.subnets : k => contains(local.reserved_subnet_names, k) ? k : "snet-${k}-${local.name_base}"
  }

  # ---------- Tags ----------

  mandatory_tags = {
    environment         = var.environment
    workload            = var.workload
    cost_center         = var.cost_center
    owner               = var.owner
    data_classification = var.data_classification
    managed_by          = "terraform"
    module              = "terraform-azurerm-virtual-network"
  }

  tags = merge(local.mandatory_tags, var.tags)

  # ---------- NSGs ----------

  subnets_with_nsg = { for k, s in var.subnets : k => s if length(s.nsg_rules) > 0 }

  nsg_rules_flat = flatten([
    for subnet_name, s in local.subnets_with_nsg : [
      for r in s.nsg_rules : merge(r, { subnet_name = subnet_name })
    ]
  ])
}
