variable "resource_group_name" {
  description = "Existing resource group to create the VNet in."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. centralus."
  type        = string
}

variable "environment" {
  description = "dev, test or prod. Used in names and tags."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "workload" {
  description = "Short name used in resource names, e.g. core."
  type        = string
}

variable "address_space" {
  description = "VNet IP ranges, e.g. [\"10.10.0.0/16\"]."
  type        = list(string)
}

variable "subnets" {
  description = "Subnets keyed by short name. Each one gets its own NSG."
  type = map(object({
    address_prefix = string
    nsg_rules = optional(list(object({
      name                = string
      priority            = number # 100-4096, lower runs first
      direction           = string # Inbound or Outbound
      access              = string # Allow or Deny
      protocol            = string # Tcp, Udp, Icmp or *
      source_address      = optional(string, "*")
      destination_address = optional(string, "*")
      destination_port    = optional(string, "*")
    })), [])
  }))
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
