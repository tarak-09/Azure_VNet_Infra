variable "resource_group_name" {
  description = "Existing resource group to create the VNet in."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. centralus."
  type        = string
}

variable "environment" {
  description = "dev, test or prod. Used in the VNet name."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "workload" {
  description = "Short name used in the VNet name, e.g. core."
  type        = string
}

variable "address_space" {
  description = "VNet IP ranges, e.g. [\"10.10.0.0/27\"]."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the VNet."
  type        = map(string)
  default     = {}
}
