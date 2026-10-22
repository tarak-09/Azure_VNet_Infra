resource_group_name = "Test-RG"
location            = "centralus"
environment         = "dev"
workload            = "core"

# Test-RG already has TestVnet on 10.0.0.0/27, so use a different range.
address_space = ["10.10.0.0/27"]

tags = {
  owner = "Vishnu"
}
