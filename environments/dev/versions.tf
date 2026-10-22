terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # No backend block: state is saved locally in terraform.tfstate (kept out of git).
}

# Uses your `az login` session and its current subscription.
provider "azurerm" {
  features {}
}
