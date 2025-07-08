variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet names to their IDs"
  type        = map(string)
}

variable "vnet_id" {
  description = "The ID of the VNet where SQL MI is deployed"
  type        = string
}

variable "mi_subnet_key" {
  description = "The key for the SQL MI subnet in the subnet_ids map"
  type        = string
  default     = "snet_dbspoke_sqlmi_poc_ pub_1"
}

variable "mi_settings" {
  description = "SQL Managed Instance configuration"
  type = object({
    name_prefix                  = string
    sku_name                     = string
    vcores                       = number
    storage_size_in_gb           = number
    administrator_login          = string
    administrator_login_password = string
    public_data_endpoint_enabled = bool
    collation                    = string
    license_type                 = string
    proxy_override               = string
    timezone_id                  = string
    minimal_tls_version          = optional(string)
    # ✅ ADD: CMK option
    transparent_data_encryption_key_vault_key_id = optional(string)
    tags                                         = map(string)
  })
}

variable "private_endpoint_config" {
  description = "Private endpoint configuration for SQL MI"
  type = map(object({
    name      = string
    subnet_id = string
    private_service_connection = object({
      name                 = string
      is_manual_connection = bool
      subresource_names    = list(string)
    })
    private_dns_zone_name = string
  }))
  default = null
}

# ✅ ADD: Random suffix variable
variable "random_suffix" {
  description = "Random suffix for resource naming consistency"
  type        = string
}

# ✅ ADD: Key Vault inputs
variable "key_vault_id" {
  description = "Key Vault ID for CMK"
  type        = string
  default     = ""
}

variable "key_vault_key_ids" {
  description = "Map of Key Vault key IDs"
  type        = map(string)
  default     = {}
}
