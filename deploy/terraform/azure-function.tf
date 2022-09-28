resource "azurerm_service_plan" "servicePlan" {
  name                = "${local.name}-plan-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main_resource_group.name
  location            = azurerm_resource_group.main_resource_group.location
  os_type             = "Windows"
  sku_name            = var.function_app_sku_size
}

resource "azurerm_windows_function_app" "dicomIngest" {
  name                = "${local.name}-function-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main_resource_group.name
  location            = azurerm_resource_group.main_resource_group.location

  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  service_plan_id            = azurerm_service_plan.servicePlan.id

  site_config {}
  app_settings = {
    STORAGE_CONNECTION_STRING = azurerm_storage_account.storage_account.primary_connection_string
  }
}
