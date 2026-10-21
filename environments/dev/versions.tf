terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81.0, < 5.0.0"
    }
  }

  # No backend: state is the local terraform.tfstate in this folder (gitignored). Don't delete
  # it; it's how Terraform knows these resources are already managed.
}

# Subscription comes from `az account set` or ARM_SUBSCRIPTION_ID; nothing is hard-coded.
provider "azurerm" {
  features {}
}
