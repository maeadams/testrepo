output "app_service_plan_ids" {
  description = "Map of App Service Plan IDs"
  value = {
    for k, v in azurerm_service_plan.main : k => v.id
  }
}

output "app_service_ids" {
  description = "Map of Web-App keys to their IDs (Windows and Linux)"
  value = merge(
    { for k, v in azurerm_linux_web_app.main : k => v.id },
    { for k, v in azurerm_windows_web_app.main : k => v.id }
  )
}

output "app_service_default_hostnames" {
  description = "Map of Web-App keys to their default host-names"
  value = merge(
    { for k, v in azurerm_linux_web_app.main : k => v.default_hostname },
    { for k, v in azurerm_windows_web_app.main : k => v.default_hostname }
  )
}

output "function_app_ids" {
  description = "Map of Function-App keys to their IDs (reserved for future use)"
  value       = {}
}

# Certificate outputs removed - not used in current configuration

# Windows Web App outputs
output "windows_web_app_ids" {
  description = "Map of Windows Web App IDs"
  value = {
    for k, v in azurerm_windows_web_app.main : k => v.id
  }
}

output "windows_web_app_default_hostnames" {
  description = "Map of Windows Web App default hostnames"
  value = {
    for k, v in azurerm_windows_web_app.main : k => v.default_hostname
  }
}

# ✅ ADDED: Linux Web App outputs
output "linux_web_app_ids" {
  description = "Map of Linux Web App IDs"
  value = {
    for k, v in azurerm_linux_web_app.main : k => v.id
  }
}

output "linux_web_app_default_hostnames" {
  description = "Map of Linux Web App default hostnames"
  value = {
    for k, v in azurerm_linux_web_app.main : k => v.default_hostname
  }
}

# Private endpoint outputs
output "private_endpoint_ids" {
  description = "Map of private endpoint IDs"
  value = {
    for k, v in azurerm_private_endpoint.webapp_private_endpoints : k => v.id
  }
}
