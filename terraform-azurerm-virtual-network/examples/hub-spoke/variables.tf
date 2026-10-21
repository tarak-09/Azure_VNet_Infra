variable "environment" {
  description = "dev, test, staging or prod."
  type        = string
}

variable "hub_resource_group_name" {
  description = "Existing resource group for the hub VNet. Its region is used for the hub."
  type        = string
}

variable "spoke_resource_group_name" {
  description = "Existing resource group for the spoke VNet. Its region is used for the spoke."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Existing Log Analytics workspace that receives VNet metrics and NSG logs."
  type        = string
}

variable "log_analytics_resource_group" {
  description = "Resource group of the Log Analytics workspace."
  type        = string
}

variable "cost_center" {
  type = string
}

variable "owner" {
  type = string
}

variable "ddos_protection_plan_id" {
  description = "DDoS Network Protection plan ID applied to both VNets, or null."
  type        = string
  default     = null
}

variable "use_remote_gateway" {
  description = "Let the spoke use the hub's VPN/ExpressRoute gateway. Requires a gateway in the hub's GatewaySubnet."
  type        = bool
  default     = false
}
