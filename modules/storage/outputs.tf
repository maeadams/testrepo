output "storage_account_names" {
  description = "Map of storage account keys to their names"
  value       = { for k, v in azurerm_storage_account.main : k => v.name }
}

output "storage_account_ids" {
  description = "Map of storage account names to their IDs"
  value = {
    for k, v in azurerm_storage_account.main : k => v.id
  }
}

output "storage_account_primary_blob_endpoints" {
  description = "Map of storage account names to their primary blob endpoints"
  value = {
    for k, v in azurerm_storage_account.main : k => v.primary_blob_endpoint
  }
}

output "storage_account_primary_access_keys" {
  description = "Map of storage account names to their primary access keys"
  value = {
    for k, v in azurerm_storage_account.main : k => v.primary_access_key
  }
  sensitive = true
}

output "storage_container_ids" {
  description = "Map of container names to their IDs"
  value = {
    for k, v in azurerm_storage_container.main : k => v.id
  }
}

output "managed_disk_ids" {
  description = "Map of managed disk names to their IDs"
  value = {
    for k, v in azurerm_managed_disk.main : k => v.id
  }
}

output "recovery_services_vault_id" {
  description = "ID of the Recovery Services Vault"
  value       = var.recovery_services_vault_config != null ? azurerm_recovery_services_vault.main[0].id : null
}

output "backup_policy_vm_ids" {
  description = "Map of VM backup policy names to their IDs."
  value       = { for k, v in azurerm_backup_policy_vm.main : k => v.id }
}

output "backup_policy_ids" {
  description = "Map of backup policy keys to their IDs"
  value       = { for k, v in azurerm_backup_policy_vm.main : k => v.id }
}

output "recovery_services_vault_name" {
  description = "Name of the Recovery Services Vault"
  value       = var.recovery_services_vault_config != null ? azurerm_recovery_services_vault.main[0].name : null
}

output "storage_summary" {
  description = "Summary of storage resources created"
  value = {
    storage_accounts   = length(azurerm_storage_account.main)
    storage_containers = length(azurerm_storage_container.main)
    managed_disks      = length(azurerm_managed_disk.main)
    recovery_vault     = var.recovery_services_vault_config != null ? 1 : 0
    backup_policies    = length(azurerm_backup_policy_vm.main)
  }
}
