resource "azurerm_service_plan" "main" {
  for_each = var.app_service_plans

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  os_type             = each.value.os_type
  sku_name            = each.value.sku_name

  tags = lookup(each.value, "tags", {})
}

################################################################################
# 2.  SPLIT WEB-APP MAPS BY OS
################################################################################
locals {
  # --------------------  WINDOWS  --------------------
  windows_apps = {
    for k, v in var.web_apps : k => v
    if lookup(v, "os_type", "Windows") == "Windows"
  }

}

################################################################################
# 3.  WINDOWS  WEB-APPS
################################################################################
resource "azurerm_windows_web_app" "main" {
  for_each = local.windows_apps

  name                          = each.value.name
  resource_group_name           = each.value.resource_group_name
  location                      = each.value.location
  service_plan_id               = azurerm_service_plan.main[each.value.service_plan_key].id
  https_only                    = lookup(each.value, "https_only", true)
  public_network_access_enabled = lookup(each.value, "public_network_access_enabled", true)
  app_settings                  = lookup(each.value, "app_settings", {})
  site_config {
    always_on         = lookup(each.value.site_config, "always_on", false)
    http2_enabled     = lookup(each.value.site_config, "http2_enabled", false)
    default_documents = lookup(each.value.site_config, "default_documents", [])
  }
    identity {
        type = lookup(each.value, "identity_type", "SystemAssigned")
    }
}