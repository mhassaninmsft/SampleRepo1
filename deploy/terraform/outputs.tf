output "rg_name" {
  value       = azurerm_resource_group.main_resource_group.name
  description = "Name of the Azure function deployed"
}
output "storage_name" {
  value       = azurerm_storage_account.storage_account.name
  description = "Name of the Azure function deployed"
}
output "function_name" {
  value       = azurerm_windows_function_app.azureFunction.name
  description = "Name of the Azure function deployed"
}
