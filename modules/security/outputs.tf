# Key Vault outputs
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.kv.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

# ✅ FIXED: Disk encryption key URL should point specifically to VM encryption key
output "disk_encryption_key_url" {
  description = "URL of the VM disk encryption key"
  value       = contains(keys(var.encryption_keys), "vm_encryption_key") ? azurerm_key_vault_key.keys["vm_encryption_key"].id : null
}

# ✅ ADD: Key Vault key IDs map
output "key_vault_key_ids" {
  description = "Map of Key Vault Key names to their IDs"
  value = {
    for k, v in azurerm_key_vault_key.keys : k => v.id
  }
}

output "key_vault_key_urls" {
  description = "URLs of Key Vault keys"
  value = try({
    for k, key in azurerm_key_vault_key.keys : k => key.versionless_id
  }, {})
}

# ✅ CRITICAL: Shared Disk Encryption Set ID
output "disk_encryption_set_id" {
  description = "ID of the shared Disk Encryption Set"
  value       = var.disk_encryption_set_config != null ? azurerm_disk_encryption_set.shared_des[0].id : null
}

# ✅ CRITICAL: DES dependency tracker for proper destroy ordering
output "des_dependency_tracker_id" {
  description = "ID of the DES dependency tracker - used by compute modules to ensure proper destroy order"
  value       = var.disk_encryption_set_config != null ? null_resource.des_dependency_tracker[0].id : null
}

output "key_vault_key_names" {
  description = "Map of Key Vault key names"
  value = try({
    for k, v in azurerm_key_vault_key.keys : k => v.name
  }, {})
}

# Key Vault Secret outputs  
output "key_vault_secret_ids" {
  description = "Map of Key Vault secret names to their IDs."
  value = try({
    for k, v in azurerm_key_vault_secret.secrets : k => v.id
  }, {})
}

output "key_vault_secret_names" {
  description = "Map of Key Vault secret names"
  value = try({
    for k, v in azurerm_key_vault_secret.secrets : k => v.name
  }, {})
}

# Azure Firewall outputs
output "firewall_id" {
  description = "ID of the Azure Firewall"
  value       = var.firewall_config != null ? azurerm_firewall.fw[0].id : null
}

output "firewall_name" {
  description = "Name of the Azure Firewall"
  value       = var.firewall_config != null ? azurerm_firewall.fw[0].name : null
}

output "firewall_policy_id" {
  description = "The ID of the Azure Firewall Policy."
  value       = var.firewall_config != null ? azurerm_firewall_policy.fw_policy[0].id : null
}

output "firewall_private_ip" {
  description = "Private IP address of Azure Firewall"
  value       = var.firewall_config != null ? azurerm_firewall.fw[0].ip_configuration[0].private_ip_address : null
}

output "firewall_public_ip_ids" {
  description = "List of Azure Firewall public IP IDs"
  value       = var.firewall_config != null ? azurerm_public_ip.fw_pip[*].id : []
}

# Application Gateway outputs
output "app_gateway_id" {
  description = "The ID of the Application Gateway"
  value       = var.app_gateway_config != null ? azurerm_application_gateway.app_gw[0].id : null
}

output "app_gateway_name" {
  description = "Application Gateway name"
  value       = var.app_gateway_config != null ? azurerm_application_gateway.app_gw[0].name : null
}

# Public IP
output "app_gateway_public_ip" {
  description = "Application Gateway public IP address"
  value       = var.app_gateway_config != null ? try(azurerm_public_ip.app_gw_pip[0].ip_address, null) : null
}

# ✅ ADD: Private IP output
output "app_gateway_private_ip" {
  description = "Application Gateway private IP address"
  value       = var.app_gateway_config != null ? try(azurerm_application_gateway.app_gw[0].frontend_ip_configuration[1].private_ip_address, null) : null
}

# Subnet ID for verification
output "app_gateway_subnet_id" {
  description = "Application Gateway subnet ID"
  value       = var.app_gateway_config != null ? try(azurerm_application_gateway.app_gw[0].gateway_ip_configuration[0].subnet_id, null) : null
}

output "app_gateway_fqdn" {
  description = "FQDN of Application Gateway"
  value       = var.app_gateway_config != null ? azurerm_public_ip.app_gw_pip[0].fqdn : null
}

output "app_gateway_public_ip_address" {
  description = "Application Gateway Public IP Address"
  value       = var.app_gateway_config != null ? azurerm_public_ip.app_gw_pip[0].ip_address : null
}


# ✅ NEW: Get actual assigned private IP from state
output "app_gateway_private_ip_actual" {
  description = "Application Gateway actual assigned private IP address"
  value       = var.app_gateway_config != null ? try(azurerm_application_gateway.app_gw[0].frontend_ip_configuration[1].private_ip_address, null) : null
}

# ✅ NEW: Application Gateway Frontend IP Configurations
output "app_gateway_frontend_ips" {
  description = "Application Gateway frontend IP configurations"
  value = var.app_gateway_config != null ? {
    public_ip  = try(azurerm_application_gateway.app_gw[0].frontend_ip_configuration[0].public_ip_address_id, null)
    private_ip = try(azurerm_application_gateway.app_gw[0].frontend_ip_configuration[1].private_ip_address, null)
  } : null
}

# WAF Policy outputs
output "web_application_firewall_policy_id" {
  description = "The ID of the Web Application Firewall Policy (if created)."
  value       = var.waf_policy_config != null ? azurerm_web_application_firewall_policy.app_gw_waf_policy[0].id : null
}

# Managed Identity outputs (if created)
output "app_gateway_identity_id" {
  description = "Application Gateway Managed Identity ID"
  value       = var.app_gateway_config != null ? azurerm_user_assigned_identity.app_gateway_identity[0].id : null
}

output "app_gateway_identity_principal_id" {
  description = "Application Gateway Managed Identity Principal ID"
  value       = var.app_gateway_config != null ? azurerm_user_assigned_identity.app_gateway_identity[0].principal_id : null
}

# Security module summary
output "security_resources_summary" {
  description = "Summary of security resources created"
  value = {
    key_vault = {
      id   = azurerm_key_vault.kv.id
      name = azurerm_key_vault.kv.name
      uri  = azurerm_key_vault.kv.vault_uri
    }
    firewall = var.firewall_config != null ? {
      id         = azurerm_firewall.fw[0].id
      name       = azurerm_firewall.fw[0].name
      private_ip = azurerm_firewall.fw[0].ip_configuration[0].private_ip_address
    } : null
    app_gateway = var.app_gateway_config != null ? {
      id   = azurerm_application_gateway.app_gw[0].id
      name = azurerm_application_gateway.app_gw[0].name
      fqdn = azurerm_public_ip.app_gw_pip[0].fqdn
    } : null
    encryption_keys = try(length(azurerm_key_vault_key.keys), 0)
    secrets_stored  = try(length(azurerm_key_vault_secret.secrets), 0)
  }
}

# Resource counts for validation
output "security_resource_count" {
  description = "Count of security resources deployed"
  value = {
    key_vaults           = 1
    encryption_keys      = try(length(azurerm_key_vault_key.keys), 0)
    secrets              = try(length(azurerm_key_vault_secret.secrets), 0)
    firewalls            = var.firewall_config != null ? 1 : 0
    firewall_policies    = var.firewall_config != null ? 1 : 0
    application_gateways = var.app_gateway_config != null ? 1 : 0
    waf_policies         = var.waf_policy_config != null ? 1 : 0
    public_ips           = (var.firewall_config != null ? var.firewall_config.public_ip_count : 0) + (var.app_gateway_config != null ? 1 : 0)
  }
}
