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