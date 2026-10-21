terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 4.x is required: subnets use `private_endpoint_network_policies` (string) and diagnostics
      # use `enabled_metric`, neither of which exists in 3.x. 4.81.0 is the lowest version this
      # module has been validated against; lower the floor only after testing an older 4.x.
      version = ">= 4.81.0, < 5.0.0"
    }
  }
}
