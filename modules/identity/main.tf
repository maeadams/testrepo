terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # For RBAC
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0" # For AAD objects
    }
  }
}

# Custom RBAC Roles (azurerm provider)
resource "azurerm_role_definition" "custom" {
  for_each = var.custom_roles

  name        = each.value.name
  description = each.value.description
  permissions {
    actions          = each.value.permissions[0].actions
    not_actions      = each.value.permissions[0].not_actions
    data_actions     = each.value.permissions[0].data_actions
    not_data_actions = each.value.permissions[0].not_data_actions
  }
  assignable_scopes = each.value.assignable_scopes
  scope             = each.value.assignable_scopes[0]
}

# Role Assignments (azurerm provider)
resource "azurerm_role_assignment" "assignment" {
  for_each = var.role_assignments

  name         = lookup(each.value, "name", null)
  principal_id = each.value.principal_id
  scope        = each.value.scope

  # ✅ FIXED: Handle both role_definition_id and role_definition_name
  role_definition_id = each.value.role_definition_id != null ? (
    contains(keys(azurerm_role_definition.custom), each.value.role_definition_id) ?
    azurerm_role_definition.custom[each.value.role_definition_id].role_definition_resource_id :
    each.value.role_definition_id
  ) : null

  role_definition_name = each.value.role_definition_name

  depends_on = [azurerm_role_definition.custom]
}

# ✅ CRITICAL: Managed Identities for Storage CMK
resource "azurerm_user_assigned_identity" "identity" {
  for_each = var.managed_identities

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  tags                = lookup(each.value, "tags", null)
}

# ✅ COMMENTED OUT: Azure AD Applications (insufficient privileges)
# Use existing web apps instead of creating new Azure AD applications
/*
resource "azuread_application" "app" {
  for_each = var.identity_providers

  display_name = each.value.name
  identifier_uris = [
    "api://${each.value.name}"
  ]
  web {
    redirect_uris = each.value.redirect_uris
  }
  required_resource_access {
    resource_app_id = each.value.required_resource_access.resource_app_id
    resource_access {
      id   = each.value.required_resource_access.resource_access.id
      type = each.value.required_resource_access.resource_access.type
    }
  }
}

resource "azuread_application_owner" "app_owner_assignment" {
  for_each = var.identity_providers

  application_id  = azuread_application.app[each.key].id
  owner_object_id = var.application_owner_object_id

  depends_on = [azuread_application.app]
}

# Azure AD Service Principals (azuread provider)
resource "azuread_service_principal" "sp" {
  for_each = var.identity_providers

  client_id = azuread_application.app[each.key].client_id
}
*/

# App Service Authentication (for OIDC/SAML) - Commented out due to deprecation and complexity of V2 resources
# The PRD lists this under both Identity and Application modules.
# For now, focusing on core AAD object creation. App Service specific auth would be in Application module using V2 resources.
/*
resource "azurerm_app_service_authentication" "auth" {
  for_each = {
    for k, auth_setting in var.app_authentication_settings : k => auth_setting
    # This logic to find app_service_id needs to be robust, ensuring app_name matches actual App Service/Function App keys
    # if lookup(var.app_services, auth_setting.app_name, null) != null || lookup(var.function_apps, auth_setting.app_name, null) != null
  }

  app_service_id = # This needs to be dynamically determined based on auth_setting.app_name
  enabled                       = each.value.enabled
  default_provider              = lookup(each.value, "default_provider", null)
  unauthenticated_client_action = lookup(each.value, "unauthenticated_client_action", "RedirectToLoginPage")
  token_store_enabled           = lookup(each.value, "token_store_enabled", true)
  issuer                        = each.value.issuer
  client_id                     = each.value.client_id # This should be the App Registration's Application (Client) ID
  client_secret_setting_name    = lookup(each.value, "client_secret_setting_name", null) # App Setting name holding the client secret
  allowed_audiences             = lookup(each.value, "allowed_audiences", null)

  dynamic "active_directory" {
    for_each = each.value.active_directory != null ? [each.value.active_directory] : []
    content {
      client_id               = active_directory.value.client_id
      client_secret_setting_name = active_directory.value.client_secret_setting_name
      allowed_audiences       = lookup(active_directory.value, "allowed_audiences", null)
    }
  }
}
*/
