terraform {
  backend "azurerm" {
  }
}

provider "azurerm" {
  features {}
}
locals {
  # build_id                    = var.environment == "e2e" ? var.build_id : ""
  name           = "terraform${var.environment}"
  sanitized_name = lower(replace(local.name, "/[^A-Za-z0-9]/", ""))
}
data "azurerm_client_config" "current" {}

data "azuread_service_principal" "az_sp_pl" {
  application_id = data.azurerm_client_config.current.client_id
}



# Resource group for persistent e2e resources
resource "azurerm_resource_group" "main_resource_group" {
  name     = "${local.name}_${random_string.suffix.result}"
  location = var.location
}


# A random suffix for resources that require unique IPs/ names
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  special = false
  lifecycle {
    ignore_changes = [
      length,
      lower,
      upper,
      special
    ]
  }
}
