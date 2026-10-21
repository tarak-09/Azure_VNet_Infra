# ---------- Placement & naming ----------

variable "resource_group_name" {
  description = "Existing resource group for the VNet. Its region is used for everything."
  type        = string
}

variable "environment" {
  description = "dev, test, staging or prod."
  type        = string
}

variable "workload" {
  description = "Short workload name used in resource names, e.g. core. Lowercase letters, digits and hyphens."
  type        = string
}

# ---------- Network ----------

variable "address_space" {
  description = "VNet address space. Must not overlap other VNets you may peer with."
  type        = list(string)
}

variable "app_subnet_prefix" {
  description = "CIDR of the app subnet. Must sit inside address_space."
  type        = string
}

# ---------- Tags ----------

variable "cost_center" {
  type = string
}

variable "owner" {
  type = string
}
