resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.workload}-${var.environment}-${var.location}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags

  # Encrypts VM-to-VM traffic for VM sizes that support it (D/E v4+ etc. with Accelerated
  # Networking). AllowUnencrypted is the only mode Azure supports today: VMs that can't
  # encrypt still communicate, just unencrypted. Free.
  encryption {
    enforcement = "AllowUnencrypted"
  }
}
