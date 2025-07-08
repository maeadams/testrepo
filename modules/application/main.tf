################################################################################
# 0.  PROVIDERS
################################################################################
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

################################################################################
# 1.  SERVICE PLANS
################################################################################
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

  # --------------------  LINUX  ----------------------
  # (fixed: default must be "Linux", not "Windows")
  linux_apps = {
    for k, v in var.web_apps : k => v
    if lookup(v, "os_type", "Linux") == "Linux"
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

  # VNet Integration
  virtual_network_subnet_id = lookup(each.value, "vnet_integration_enabled", false) ? var.subnet_ids[each.value.vnet_integration_subnet] : null

  site_config {
    always_on         = lookup(each.value.site_config, "always_on", false)
    http2_enabled     = lookup(each.value.site_config, "http2_enabled", false)
    default_documents = lookup(each.value.site_config, "default_documents", [])

    # Route-all when VNet integration enabled
    vnet_route_all_enabled = lookup(each.value, "vnet_integration_enabled", false)

    # IP restrictions
    ip_restriction_default_action = length(lookup(each.value, "ip_restrictions", [])) > 0 ? "Deny" : "Allow"

    dynamic "ip_restriction" {
      for_each = lookup(each.value, "ip_restrictions", [])
      content {
        name       = lookup(ip_restriction.value, "name", null)
        ip_address = lookup(ip_restriction.value, "ip_address", null)
        priority   = lookup(ip_restriction.value, "priority", null)
        action     = lookup(ip_restriction.value, "action", "Allow")
      }
    }
  }

  tags = lookup(each.value, "tags", {})

  # Ignore Azure-managed setting changes
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_VNET_ROUTE_ALL"],
      app_settings["WEBSITE_DNS_SERVER"],
      app_settings["WEBSITE_CONTENTOVERVNET"]
    ]
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      setlocal enableextensions enabledelayedexpansion
      if "${each.key}"=="webapp_exposed" (
        az webapp deploy --resource-group ${each.value.resource_group_name} --name ${each.value.name} --src-path "${path.module}/../../webapp-content/index-exposed.html" --type static --target-path "site/wwwroot/index.html"
      ) else if "${each.key}"=="webapp_nonexposed" (
        az webapp deploy --resource-group ${each.value.resource_group_name} --name ${each.value.name} --src-path "${path.module}/../../webapp-content/index-nonexposed.html" --type static --target-path "site/wwwroot/index.html"
      )
    EOT
    interpreter = ["cmd.exe", "/C"]
  }
}

################################################################################
# 4.  LINUX  WEB-APPS
################################################################################
resource "azurerm_linux_web_app" "main" {
  for_each = local.linux_apps

  name                          = each.value.name
  resource_group_name           = each.value.resource_group_name
  location                      = each.value.location
  service_plan_id               = azurerm_service_plan.main[each.value.service_plan_key].id
  https_only                    = lookup(each.value, "https_only", true)
  public_network_access_enabled = lookup(each.value, "public_network_access_enabled", true)
  app_settings                  = lookup(each.value, "app_settings", {})

  # VNet Integration
  virtual_network_subnet_id = lookup(each.value, "vnet_integration_enabled", false) ? var.subnet_ids[each.value.vnet_integration_subnet] : null

  site_config {
    always_on         = lookup(each.value.site_config, "always_on", false)
    http2_enabled     = lookup(each.value.site_config, "http2_enabled", false)
    linux_fx_version  = lookup(each.value.site_config, "linux_fx_version", null)
    default_documents = lookup(each.value.site_config, "default_documents", [])

    vnet_route_all_enabled = lookup(each.value, "vnet_integration_enabled", false)

    # IP restrictions
    ip_restriction_default_action = length(lookup(each.value, "ip_restrictions", [])) > 0 ? "Deny" : "Allow"

    dynamic "ip_restriction" {
      for_each = lookup(each.value, "ip_restrictions", [])
      content {
        name       = lookup(ip_restriction.value, "name", null)
        ip_address = lookup(ip_restriction.value, "ip_address", null)
        priority   = lookup(ip_restriction.value, "priority", null)
        action     = lookup(ip_restriction.value, "action", "Allow")
      }
    }
  }

  tags = lookup(each.value, "tags", {})

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_VNET_ROUTE_ALL"],
      app_settings["WEBSITE_DNS_SERVER"],
      app_settings["WEBSITE_CONTENTOVERVNET"]
    ]
  }
}

################################################################################
# 5.  PRIVATE ENDPOINTS (INBOUND)
################################################################################
locals {
  # Which apps need a private endpoint?
  private_endpoint_apps = {
    for k, v in var.web_apps : k => v
    if lookup(v, "private_endpoint_enabled", false)
  }

  # Validation flags
  subnet_ids_available = var.subnet_ids != null && length(var.subnet_ids) > 0
  dns_zone_available   = var.private_dns_zone_ids != null && lookup(var.private_dns_zone_ids, "privatelink.azurewebsites.net", null) != null
}

resource "azurerm_private_endpoint" "webapp_private_endpoints" {
  for_each = local.subnet_ids_available ? local.private_endpoint_apps : {}

  name                = "pep-${each.value.name}"
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  subnet_id           = var.subnet_ids[each.value.private_endpoint_subnet]

  private_service_connection {
    name                           = "psc-${each.value.name}"
    private_connection_resource_id = lookup(each.value, "os_type", "Windows") == "Windows" ? azurerm_windows_web_app.main[each.key].id : azurerm_linux_web_app.main[each.key].id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  # Create DNS zone group only if zone is supplied
  dynamic "private_dns_zone_group" {
    for_each = local.dns_zone_available ? [1] : []
    content {
      name                 = "pdzg-${each.value.name}"
      private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.azurewebsites.net"]]
    }
  }

  tags = lookup(each.value, "tags", {})

  depends_on = [
    azurerm_windows_web_app.main,
    azurerm_linux_web_app.main
  ]
}

################################################################################
# 6.  OUTPUTS
################################################################################
output "private_endpoint_summary" {
  description = "Summary of private endpoint creation"
  value = {
    apps_with_private_endpoints = keys(local.private_endpoint_apps)
    private_endpoints_created   = keys(azurerm_private_endpoint.webapp_private_endpoints)
    subnet_ids_available        = local.subnet_ids_available
    dns_zone_available          = local.dns_zone_available
  }
}
