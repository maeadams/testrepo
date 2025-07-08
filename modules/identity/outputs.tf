output "managed_identity_ids" {
  description = "IDs of managed identities"
  value = try({
    for k, msi in azurerm_user_assigned_identity.identity : k => msi.id
  }, {})
}

output "managed_identity_principal_ids" {
  description = "Principal IDs of managed identities"
  value = try({
    for k, msi in azurerm_user_assigned_identity.identity : k => msi.principal_id
  }, {})
}

output "managed_identity_client_ids" {
  description = "Client IDs of managed identities"
  value = try({
    for k, msi in azurerm_user_assigned_identity.identity : k => msi.client_id
  }, {})
}

# ✅ COMMENTED OUT: Azure AD Application outputs (resources are commented out due to insufficient privileges)
/*
output "application_ids" {
  description = "Map of application resource IDs"
  value = try({
    for k, v in azuread_application.app : k => v.id
  }, {})
}

output "service_principal_ids" {
  description = "Map of identity provider names to service principal IDs"
  value = try({
    for k, v in azuread_service_principal.sp : k => v.id
  }, {})
}

output "application_client_ids" {
  description = "Map of identity provider logical names to their Azure AD Application (Client) IDs."
  value = try({
    for k, v in azuread_application.app : k => v.client_id
  }, {})
}

output "application_object_ids" {
  description = "Map of application object IDs"
  value = try({
    for k, v in azuread_application.app : k => v.object_id
  }, {})
}

output "service_principal_object_ids" {
  description = "Map of service principal object IDs"
  value = try({
    for k, v in azuread_service_principal.sp : k => v.object_id
  }, {})
}
*/

# Placeholder outputs for Azure AD resources (when permissions are available)
output "application_ids" {
  description = "Map of application resource IDs (empty - Azure AD resources commented out)"
  value       = {}
}

output "service_principal_ids" {
  description = "Map of identity provider names to service principal IDs (empty - Azure AD resources commented out)"
  value       = {}
}

output "application_client_ids" {
  description = "Map of identity provider logical names to their Azure AD Application (Client) IDs (empty - Azure AD resources commented out)"
  value       = {}
}

output "application_object_ids" {
  description = "Map of application object IDs (empty - Azure AD resources commented out)"
  value       = {}
}

output "service_principal_object_ids" {
  description = "Map of service principal object IDs (empty - Azure AD resources commented out)"
  value       = {}
}

#   ADD: Custom role definition IDs output
output "custom_role_definition_ids" {
  description = "Map of custom role definition names to their IDs."
  value = try({
    for k, v in azurerm_role_definition.custom : k => v.id
  }, {})
}
