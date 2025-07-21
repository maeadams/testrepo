variable "resource_groups" {
  description = "Resource group configurations"
  type = map(object({
    name     = string
    location = string
    tags     = optional(map(string))
  }))
}
variable "managed_identities" {
  description = "Configuration for Managed Identities."
  type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    tags                = optional(map(string))
  }))
  default = {}
}
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