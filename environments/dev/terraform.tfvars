resource_group_name = "Test-RG"
location            = "centralus"
environment         = "dev"
workload            = "core"

# Test-RG already has TestVnet on 10.0.0.0/27, so use a different range.
address_space = ["10.10.0.0/16"]

subnets = {
  app = {
    address_prefix = "10.10.1.0/24"
  }

  # Example of a subnet with its own NSG rule:
  # web = {
  #   address_prefix = "10.10.2.0/24"
  #   nsg_rules = [
  #     { name = "allow-https", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", destination_port = "443" },
  #   ]
  # }
}

tags = {
  owner       = "tarak"
  cost_center = "cc-dev"
}
