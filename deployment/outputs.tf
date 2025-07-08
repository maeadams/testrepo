# =============================================================================
# OUTPUTS - COMMERCIAL AZURE LANDING ZONE POC
# =============================================================================

# Network Outputs
output "hub_vnet_id" {
  description = "ID of the Hub Virtual Network"
  value       = try(module.network.hub_vnet_id, "")
}

output "spoke_vnet_ids" {
  description = "IDs of Spoke Virtual Networks"
  value       = try(module.network.spoke_vnet_ids, {})
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value       = module.network.subnet_ids
}

output "expressroute_gateway_id" {
  description = "ID of the ExpressRoute Gateway"
  value       = try(module.network.expressroute_gateway_id, "")
}

output "bastion_host_fqdn" {
  description = "FQDN of Azure Bastion Host"
  value       = try(module.network.bastion_host_fqdn, "")
}

# Security Outputs
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = try(module.security.key_vault_uri, "")
}

output "firewall_private_ip" {
  description = "Private IP address of Azure Firewall"
  value       = try(module.security.firewall_private_ip, "")
}

output "app_gateway_public_ip" {
  description = "Public IP address of Application Gateway"
  value       = try(module.security.app_gateway_public_ip, "")
}

output "app_gateway_fqdn" {
  description = "FQDN of Application Gateway"
  value       = try(module.security.app_gateway_fqdn, "")
}

# ✅ NEW: Application Gateway Private IP
output "app_gateway_private_ip" {
  description = "Application Gateway private IP address"
  value       = module.security.app_gateway_private_ip
}

# ✅ NEW: Application Gateway Frontend IPs
output "app_gateway_frontend_ips" {
  description = "Application Gateway frontend IP configurations"
  value       = module.security.app_gateway_frontend_ips
}

# Application Outputs
output "connected_webapp_fqdn" {
  description = "FQDN of the exposed web application (via App Gateway)"
  value       = try(module.fe_exposed_webapp.windows_web_app_default_hostnames["webapp_exposed"], "")
}

output "nonconnected_webapp_fqdn" {
  description = "FQDN of the non-exposed web application (internal access only)"
  value       = try(module.fe_nonexposed_webapp.windows_web_app_default_hostnames["webapp_nonexposed"], "")
}

output "connected_webapp_id" {
  description = "ID of the exposed web application"
  value       = try(module.fe_exposed_webapp.windows_web_app_ids["webapp_exposed"], "")
}

output "nonconnected_webapp_id" {
  description = "ID of the non-exposed web application"
  value       = try(module.fe_nonexposed_webapp.windows_web_app_ids["webapp_nonexposed"], "")
}

# Web App Access URLs
output "exposed_webapp_url" {
  description = "URL to access exposed web app via App Gateway"
  value       = try("https://${module.security.app_gateway_public_ip}/", "")
}

output "nonexposed_webapp_url" {
  description = "URL to access non-exposed web app (internal only)"
  value       = try("https://${module.fe_nonexposed_webapp.windows_web_app_default_hostnames["webapp_nonexposed"]}/", "")
}

# Database Outputs
output "sql_mi_fqdn" {
  description = "FQDN of SQL Managed Instance"
  value       = try(module.database.sql_mi_fqdn, "")
}

output "sql_mi_id" {
  description = "ID of SQL Managed Instance"
  value       = try(module.database.sql_mi_id, "")
}

# Monitoring Outputs
output "log_analytics_workspace_id" {
  description = "ID of Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_name
}

# Identity Outputs
output "managed_identity_ids" {
  description = "IDs of created managed identities"
  value       = try(module.identity.managed_identity_ids, {})
}

output "managed_identity_principal_ids" {
  description = "Principal IDs of created managed identities"
  value       = try(module.identity.managed_identity_principal_ids, {})
}

# Storage Outputs
output "storage_account_ids" {
  description = "IDs of created storage accounts"
  value       = module.storage.storage_account_ids
}

output "storage_account_primary_endpoints" {
  description = "Primary blob endpoints of storage accounts"
  value       = try(module.storage.storage_account_primary_blob_endpoints, {})
}

# ✅ NEW: NAT Gateway Outputs
output "nat_gateway_id" {
  description = "ID of the NAT Gateway for expose spoke"
  value       = try(module.network.nat_gateway_id, "")
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = try(module.network.nat_gateway_public_ip, "")
}

# ✅ NEW: DNS Resolver Outputs
output "dns_resolver_id" {
  description = "ID of the Hub DNS Resolver"
  value       = try(module.network.dns_resolver_id, "")
}

output "dns_resolver_inbound_endpoint_ip" {
  description = "IP address of the DNS Resolver inbound endpoint"
  value       = try(module.network.dns_resolver_inbound_endpoint_ip, "")
}

# ✅ NEW: VNet Peering Outputs
output "vnet_peering_hub_to_spoke" {
  description = "Map of hub-to-spoke VNet peering IDs"
  value       = try(module.network.vnet_peering_hub_to_spoke, {})
}

output "vnet_peering_spoke_to_hub" {
  description = "Map of spoke-to-hub VNet peering IDs"
  value       = try(module.network.vnet_peering_spoke_to_hub, {})
}

# ✅ FIXED: Compute Outputs from multiple compute modules
output "windows_vm_ids" {
  description = "Map of Windows VM names to their IDs from all compute modules"
  value = merge(
    try(module.compute.windows_vm_ids, {}),
    try(module.onprem_compute.windows_vm_ids, {}),
    try(module.fe_exposed_compute.windows_vm_ids, {}),
    try(module.fe_nonexposed_compute.windows_vm_ids, {})
  )
}

output "admin_vm_private_ip" {
  description = "Private IP address of the Admin VM (in Hub)"
  value       = try(module.compute.windows_vm_private_ips["admin_vm"], "")
}

output "onprem_vm_private_ip" {
  description = "Private IP address of the OnPrem VM"
  value       = try(module.onprem_compute.windows_vm_private_ips["vm_onprem_server"], "")
}

