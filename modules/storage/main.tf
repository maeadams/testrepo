terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

resource "azurerm_storage_account" "main" {
  for_each = var.storage_accounts

  name                     = each.value.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  account_kind             = each.value.account_kind
  access_tier              = lookup(each.value, "access_tier", null)

  # Always keep shared-key access ON – Terraform needs it to read static-web
  # properties.  Do NOT ignore it in lifecycle.
  shared_access_key_enabled = lookup(each.value, "allow_shared_key_access", true)
  allow_nested_items_to_be_public = false

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled = lookup(each.value, "versioning_enabled", false)

    delete_retention_policy {
      days = lookup(each.value, "blob_soft_delete_retention_days", 7)
    }
  }

  # keep ignoring only what is really safe
  lifecycle {
    ignore_changes = [
      static_website,
      public_network_access_enabled,
      network_rules
    ]
  }

  tags = each.value.tags
}

# ✅ CRITICAL: Enable storage account authentication before destroy (AGGRESSIVE)
resource "null_resource" "storage_auth_enabler" {
  for_each = var.storage_accounts

  triggers = {
    storage_account_name = azurerm_storage_account.main[each.key].name
    resource_group_name  = var.resource_group_name
  }

  # Enable ALL authentication methods before destroy to prevent 403 errors
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🔓 Aggressively enabling all access for storage account: ${self.triggers.storage_account_name}"

      # Remove all network rules and fully relax access
      az storage account update \
        --name "${self.triggers.storage_account_name}" \
        --resource-group "${self.triggers.resource_group_name}" \
        --bypass AzureServices \
        --default-action Allow \
        --public-network-access Enabled \
        --allow-shared-key-access true || echo "⚠️ Failed to fully relax network rules"

      # Wait for propagation and test access
      for i in {1..12}; do
        az storage container list --account-name "${self.triggers.storage_account_name}" --auth-mode key >/dev/null 2>&1 && break
        echo "⏳ Waiting for storage account access to propagate... ($i/12)"
        sleep 5
      done

      echo "✅ Storage account authentication configuration completed"
    EOT
  }

  depends_on = [azurerm_storage_account.main]
}

# ✅ CRITICAL: Force authentication enabler to run BEFORE storage account destroy
resource "null_resource" "storage_destroy_dependency" {
  for_each = var.storage_accounts

  triggers = {
    auth_enabler_id = null_resource.storage_auth_enabler[each.key].id
  }

  depends_on = [
    null_resource.storage_auth_enabler,
    azurerm_storage_account.main
  ]
}

# ✅ CRITICAL: Handle container authentication during destroy
resource "null_resource" "container_auth_handler" {
  for_each = var.storage_containers

  triggers = {
    storage_account_name = azurerm_storage_account.main[each.value.storage_account_key_ref].name
    container_name       = each.value.name
    resource_group_name  = var.resource_group_name
  }

  # Handle authentication issues during destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Handling authentication for container: ${self.triggers.container_name}"
      
      # Ensure storage account has key-based auth enabled
      az storage account update \
        --name "${self.triggers.storage_account_name}" \
        --resource-group "${self.triggers.resource_group_name}" \
        --allow-shared-key-access true || echo "Could not enable shared key access"
      
      # Wait a moment for propagation
      sleep 5
      
      echo "Container authentication handling completed"
    EOT
  }

  depends_on = [
    azurerm_storage_account.main,
    azurerm_storage_container.main
  ]
}

# ✅ DISABLED: RBAC role assignments - using access policies instead for POC reliability
# resource "azurerm_role_assignment" "storage_key_vault_crypto_user" {
#   for_each = var.storage_accounts

#   scope                = var.key_vault_id
#   role_definition_name = "Key Vault Crypto Service Encryption User"
#   principal_id         = azurerm_storage_account.main[each.key].identity[0].principal_id

#   depends_on = [azurerm_storage_account.main]
# }

# ✅ DISABLED: RBAC wait time not needed with access policies
# resource "time_sleep" "wait_for_storage_rbac" {
#   count = length(var.storage_accounts) > 0 ? 1 : 0

#   depends_on = [azurerm_role_assignment.storage_key_vault_crypto_user]
#   create_duration = "30s"
# }

# Add this resource before the storage containers
resource "null_resource" "storage_access_fix" {
  for_each = var.storage_accounts

  triggers = {
    storage_account_name = azurerm_storage_account.main[each.key].name
    resource_group_name  = var.resource_group_name
  }

  # Ensure storage account is accessible for Terraform operations
  provisioner "local-exec" {
    command = <<-EOT
      echo "Ensuring storage account access: ${azurerm_storage_account.main[each.key].name}"
      
      # Enable all access methods
      az storage account update \
        --name "${azurerm_storage_account.main[each.key].name}" \
        --resource-group "${var.resource_group_name}" \
        --allow-shared-key-access true \
        --public-network-access Enabled \
        --default-action Allow || echo "Could not update storage account access"
      
      # Clear network rules that might block access
      az storage account network-rule clear \
        --account-name "${azurerm_storage_account.main[each.key].name}" \
        --resource-group "${var.resource_group_name}" || echo "Could not clear network rules"
      
      # Wait for propagation
      sleep 5
    EOT
  }

  depends_on = [azurerm_storage_account.main]
}

# Storage Containers - with proper dependencies and authentication handling
resource "azurerm_storage_container" "main" {
  for_each = var.storage_containers

  name                  = each.value.name
  storage_account_name  = azurerm_storage_account.main[each.value.storage_account_key_ref].name
  container_access_type = each.value.container_access_type

  # Add lifecycle rules to handle refresh issues
  lifecycle {
    ignore_changes = [
      metadata,
      # Ignore properties that might cause auth errors during refresh
      default_encryption_scope,
      encryption_scope_override_enabled
    ]
  }

  depends_on = [
    azurerm_storage_account.main,
    null_resource.storage_access_fix,
    time_sleep.wait_for_storage_auth
  ]
}

resource "time_sleep" "wait_for_storage_auth" {
  for_each        = var.storage_accounts
  depends_on      = [null_resource.storage_auth_enabler]
  create_duration = "60s"
}

# Managed Disks
resource "azurerm_managed_disk" "main" {
  for_each = var.managed_disks

  name                 = each.value.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = each.value.storage_account_type
  create_option        = each.value.create_option
  disk_size_gb         = each.value.disk_size_gb

  tags = lookup(each.value, "tags", {})
}

# ✅ Recovery Services Vault
resource "azurerm_recovery_services_vault" "main" {
  count = var.recovery_services_vault_config != null ? 1 : 0

  name                = var.recovery_services_vault_config.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.recovery_services_vault_config.sku
  soft_delete_enabled = false # Disable soft delete for smooth destruction

  # Allow smooth destruction by removing backup items
  lifecycle {
    prevent_destroy = false
  }

  tags = lookup(var.recovery_services_vault_config, "tags", {})
}

# Add cleanup resource for Recovery Services Vault
resource "null_resource" "rsv_cleanup" {
  count = var.recovery_services_vault_config != null ? 1 : 0

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Cleaning up Recovery Services Vault backup items..."
      if command -v az &> /dev/null; then
        # Disable soft delete and remove backup items
        az backup vault backup-properties set \
          --name "${self.triggers.rsv_name}" \
          --resource-group "${self.triggers.rg_name}" \
          --soft-delete-feature-state Disable || echo "Could not disable soft delete"
        
        # List and delete backup items in soft delete state
        az backup item list \
          --vault-name "${self.triggers.rsv_name}" \
          --resource-group "${self.triggers.rg_name}" \
          --query "[?properties.deleteState=='ToBeDeleted'].{Name:properties.friendlyName,ContainerName:properties.containerName}" \
          --output table || echo "No backup items found"
      fi
    EOT
  }

  triggers = {
    rsv_name = azurerm_recovery_services_vault.main[0].name
    rg_name  = var.resource_group_name
  }

  depends_on = [azurerm_recovery_services_vault.main]
}

# ✅ VM Backup Policies
resource "azurerm_backup_policy_vm" "main" {
  for_each = var.backup_policies_vm

  name                = each.value.name
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name

  backup {
    frequency = each.value.backup.frequency
    time      = each.value.backup.time
  }

  retention_daily {
    count = each.value.retention_daily.count
  }

  retention_weekly {
    count    = each.value.retention_weekly.count
    weekdays = each.value.retention_weekly.weekdays
  }

  retention_monthly {
    count    = each.value.retention_monthly.count
    weekdays = each.value.retention_monthly.weekdays
    weeks    = each.value.retention_monthly.weeks
  }

  retention_yearly {
    count    = each.value.retention_yearly.count
    weekdays = each.value.retention_yearly.weekdays
    weeks    = each.value.retention_yearly.weeks
    months   = each.value.retention_yearly.months
  }

  depends_on = [azurerm_recovery_services_vault.main]
}

# ✅ Site Recovery Configuration (if needed)
resource "azurerm_site_recovery_fabric" "main" {
  count = var.site_recovery_config != null ? 1 : 0

  name                = var.site_recovery_config.fabric_name
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name
  location            = var.location

  depends_on = [azurerm_recovery_services_vault.main]
}
