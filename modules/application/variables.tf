variable "resource_group_name" {
  type        = string
  description = "Deprecated – kept for backward compatibility"
  default     = null
}

variable "location" {
  type        = string
  description = "Deprecated – kept for backward compatibility"
  default     = null
}

variable "app_services" {
  type        = map(any)
  description = "Deprecated – replaced by web_apps"
  default     = {}
}


variable "subnet_ids" {
  description = "Map of subnet IDs for VNet integration and private endpoints"
  type        = map(string)
}

variable "private_dns_zone_ids" {
  description = "Map of private DNS zone IDs for private endpoints"
  type        = map(string)
}

# ✅ App Service Plans variable definition
variable "app_service_plans" {
  description = "Map of App Service Plan configurations"
  type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    os_type             = string # ✅ "Windows" or "Linux"
    sku_name            = string
    tags                = optional(map(string), {})
  }))
}


variable "web_apps" {
  description = "Map of web-apps to deploy (Windows or Linux)"
  type        = map(any)
}

variable "function_apps" {
  description = "Function App configurations"
  type = map(object({
    name                       = string
    app_service_plan_id        = string # ID of the App Service Plan
    storage_account_name       = string
    storage_account_access_key = string # Sensitive
    https_only                 = optional(bool, true)
    version                    = optional(string, "~4") # Function runtime version
    site_config = optional(object({
      always_on        = optional(bool)
      linux_fx_version = optional(string) # e.g., "DOTNET|6.0"
      dotnet_version   = optional(string) # For Windows, e.g. "v6.0"
    }))
    app_settings               = optional(map(string))
    vnet_integration_subnet_id = optional(string)
    tags                       = optional(map(string))
  }))
  default = {}
}

variable "app_service_custom_hostnames" {
  description = "Custom hostname bindings for App Services"
  type = map(object({
    app_service_name = string
    hostname         = string
    ssl_state        = optional(string) # "SniEnabled" or "IpBasedEnabled"
    thumbprint       = optional(string) # Required if ssl_state is set
  }))
  default = {}
}

variable "app_service_certificates" {
  description = "SSL certificates for App Services"
  type = map(object({
    name                = string
    app_service_name    = string
    pfx_blob            = optional(string) # Base64 encoded PFX blob
    password            = optional(string) # Sensitive
    key_vault_secret_id = optional(string) # Alternative to PFX blob
    tags                = optional(map(string))
  }))
  default = {}
}

variable "app_authentication_settings" {
  description = "Authentication settings for App Services"
  type = map(object({
    app_service_key               = string
    enabled                       = bool
    unauthenticated_client_action = string
    default_provider              = string
    active_directory_settings = object({
      client_id                  = string
      allowed_audiences          = list(string)
      client_secret_setting_name = string
    })
  }))
  default = {}
}

# ✅ NOTE: Variables already exist above - duplicates removed
