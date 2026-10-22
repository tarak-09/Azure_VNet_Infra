# Values are set in terraform.tfvars. See the module's variables.tf for details.

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "workload" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "subnets" {
  type = map(object({
    address_prefix = string
    nsg_rules = optional(list(object({
      name                = string
      priority            = number
      direction           = string
      access              = string
      protocol            = string
      source_address      = optional(string, "*")
      destination_address = optional(string, "*")
      destination_port    = optional(string, "*")
    })), [])
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
