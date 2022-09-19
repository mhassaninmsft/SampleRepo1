terraform {
  backend "azurerm" {
  }
}

provider "azurerm" {
  features {}
}

locals {
  build_id = "1237"
}

data "azurerm_client_config" "current" {}

data "azuread_service_principal" "az_sp_pl" {
  application_id = data.azurerm_client_config.current.client_id
}

# Resource group for persistent e2e resources
resource "azurerm_resource_group" "main_rg" {
  name     = "terraform_rg_123"
  location = "eastus"
}
