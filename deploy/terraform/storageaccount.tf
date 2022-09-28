# Storage Account

resource "azurerm_storage_account" "storage_account" {
  name                     = "${local.sanitized_name}stor${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main_resource_group.name
  location                 = azurerm_resource_group.main_resource_group.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.storage_account_replication_type

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 365
    }
    container_delete_retention_policy {
      days = 7
    }
  }
  # lifecycle {
  #   prevent_destroy = false
  # }
}
