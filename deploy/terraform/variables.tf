variable "location" {
  type        = string
  default     = "eastus"
  description = "The Azure location name for deployed resources"
}

variable "environment" {
  type        = string
  description = "The environment name corresponding to this deployment"
}

variable "function_app_sku_size" {
  type        = string
  default     = "Y1"
  description = "The Azure Function app SKU size"
}


variable "storage_account_replication_type" {
  type        = string
  default     = "LRS"
  description = "Replication type of the storage account , for example Locally Redundnat or Geo Redundant"
}
