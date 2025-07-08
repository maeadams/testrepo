data "azurerm_client_config" "current" {}

# ✅ CRITICAL: Disk Encryption Set - NO circular dependency
resource "azurerm_disk_encryption_set" "shared_des" {
  count = var.disk_encryption_set_config != null ? 1 : 0

  name                = "${var.disk_encryption_set_config.name_prefix}-shared-${var.random_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  key_vault_key_id    = var.encryption_keys["vm_encryption_key"] != null ? azurerm_key_vault_key.keys["vm_encryption_key"].id : null
  tags                = lookup(var.disk_encryption_set_config, "tags", null)

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    create_before_destroy = true
    prevent_destroy = false
    ignore_changes = [
      key_vault_key_id  # Prevent recreation due to key rotation
    ]
  }

  # ✅ FIXED: Only depend on Key Vault and keys - NO destroy protection dependency
  depends_on = [
    azurerm_key_vault.kv,
    azurerm_key_vault_key.keys
  ]
}

# ✅ CRITICAL: Key Vault destroy protection - AFTER DES creation
# resource "null_resource" "kv_destroy_protection" {
#   triggers = {
#     key_vault_id = azurerm_key_vault.kv.id
#     des_id = var.disk_encryption_set_config != null ? azurerm_disk_encryption_set.shared_des[0].id : ""
#     resource_group = var.resource_group_name
#   }

#   # This resource will be destroyed AFTER all compute resources
#   # preventing Key Vault from being deleted while VMs still need it
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       echo "🔑 Key Vault destroy protection active"
#       echo "Key Vault: ${self.triggers.key_vault_id}"
#       echo "DES: ${self.triggers.des_id}"
#       echo "All dependent resources must be destroyed before this Key Vault"
#     EOT
#   }

#   lifecycle {
#     create_before_destroy = false
#   }

#   # ✅ FIXED: Depend on both Key Vault AND DES after they're created (no circular dependency)
#   depends_on = [
#     azurerm_key_vault.kv,
#     azurerm_disk_encryption_set.shared_des
#   ]
# }

# ✅ IMPROVED: Access Policy with better destroy handling
resource "azurerm_key_vault_access_policy" "shared_des_access_policy" {
  count = var.disk_encryption_set_config != null ? 1 : 0

  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_disk_encryption_set.shared_des[0].identity[0].principal_id

  key_permissions = [
    "Get", "UnwrapKey", "WrapKey"
  ]

  lifecycle {
    create_before_destroy = true
    prevent_destroy = false
    # ✅ CRITICAL: Ignore changes if DES is being destroyed
    ignore_changes = [
      object_id  # Ignore if the DES identity no longer exists
    ]
  }

  depends_on = [
    azurerm_disk_encryption_set.shared_des,
    azurerm_key_vault.kv
  ]
}

# ✅ NEW: Force cleanup of access policies before DES destruction
# resource "null_resource" "cleanup_des_access_policy" {
#   count = var.disk_encryption_set_config != null ? 1 : 0

#   triggers = {
#     des_principal_id = azurerm_disk_encryption_set.shared_des[0].identity[0].principal_id
#     key_vault_name   = azurerm_key_vault.kv.name
#     resource_group   = var.resource_group_name
#   }

#   # Clean up access policy manually before DES is destroyed
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       echo "🧹 Cleaning up DES access policy before DES destruction..."
      
#       if ! command -v az >/dev/null 2>&1; then
#         echo "Azure CLI not found - skipping cleanup"
#         exit 0
#       fi
      
#       # Remove the specific access policy for the DES
#       echo "Removing access policy for DES: ${self.triggers.des_principal_id}"
#       az keyvault delete-policy \
#         --name "${self.triggers.key_vault_name}" \
#         --resource-group "${self.triggers.resource_group}" \
#         --object-id "${self.triggers.des_principal_id}" 2>/dev/null || echo "Access policy already removed or DES deleted"
      
#       echo "✅ DES access policy cleanup completed"
#     EOT
#   }

#   depends_on = [
#     azurerm_disk_encryption_set.shared_des,
#     azurerm_key_vault_access_policy.shared_des_access_policy
#   ]
# }

# ✅ CRITICAL: Destroy-time Key Vault access enabler
# resource "null_resource" "kv_des_access_during_destroy" {
#   count = var.disk_encryption_set_config != null ? 1 : 0

#   triggers = {
#     key_vault_name = azurerm_key_vault.kv.name
#     resource_group = var.resource_group_name
#     des_principal_id = azurerm_disk_encryption_set.shared_des[0].identity[0].principal_id
#     tenant_id = data.azurerm_client_config.current.tenant_id
#   }

#   # Enable Key Vault access for destroy operations
#   provisioner "local-exec" {
#     when = destroy
#     command = <<-EOT
#       set -e
#       echo "Ensuring Key Vault access for DES during destroy..."
      
#       # Function to retry command
#       retry_command() {
#         local cmd="$1"
#         local max_attempts=5
#         local attempt=1
        
#         while [ $attempt -le $max_attempts ]; do
#           echo "Attempt $attempt: $cmd"
#           if eval "$cmd"; then
#             return 0
#           fi
#           attempt=$((attempt + 1))
#           if [ $attempt -le $max_attempts ]; then
#             echo "Retrying in 10 seconds..."
#             sleep 10
#           fi
#         done
#         echo "Command failed after $max_attempts attempts: $cmd"
#         return 1
#       }
      
#       # Check if Azure CLI is available
#       if ! command -v az >/dev/null 2>&1; then
#         echo "Azure CLI not found - skipping Key Vault access setup"
#         exit 0
#       fi
      
#       # Enable public network access for destroy operations
#       echo "Enabling Key Vault public access for destroy operations..."
#       retry_command "az keyvault update --name '${self.triggers.key_vault_name}' --resource-group '${self.triggers.resource_group}' --public-network-access Enabled" || echo "Failed to enable public access"
      
#       # Ensure DES has access policies
#       echo "Ensuring DES access policy exists..."
#       retry_command "az keyvault set-policy --name '${self.triggers.key_vault_name}' --resource-group '${self.triggers.resource_group}' --object-id '${self.triggers.des_principal_id}' --key-permissions get unwrapKey wrapKey" || echo "Failed to set DES access policy"
      
#       # Allow current user access for Terraform operations with ALL required permissions
#       echo "Ensuring Terraform access to Key Vault..."
#       CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
#       if [ -n "$CURRENT_USER_ID" ]; then
#         retry_command "az keyvault set-policy --name '${self.triggers.key_vault_name}' --resource-group '${self.triggers.resource_group}' --object-id '$CURRENT_USER_ID' --key-permissions backup create decrypt delete encrypt get import list purge recover restore sign unwrapKey update verify wrapKey release rotate getRotationPolicy setRotationPolicy --secret-permissions backup delete get list purge recover restore set" || echo "Failed to set user access policy"
#       fi
      
#       echo "Key Vault access setup completed"
#     EOT
#   }

#   depends_on = [
#     azurerm_disk_encryption_set.shared_des,
#     azurerm_key_vault_access_policy.shared_des_access_policy
#   ]
# }

# # ✅ ENHANCED: Wait for access policy before VM creation
# resource "time_sleep" "wait_for_shared_des_permissions" {
#   count = var.disk_encryption_set_config != null ? 1 : 0

#   depends_on = [
#     azurerm_disk_encryption_set.shared_des,
#     azurerm_key_vault_access_policy.shared_des_access_policy
#   ]
#   create_duration = "30s"  # ✅ Wait for access policy propagation
# }

# # ✅ CRITICAL: DES dependency tracker - prevents DES deletion until all compute resources signal completion
# resource "null_resource" "des_dependency_tracker" {
#   count = var.disk_encryption_set_config != null ? 1 : 0

#   triggers = {
#     des_id = azurerm_disk_encryption_set.shared_des[0].id
#     # This resource will be referenced by compute modules to create proper dependencies
#     timestamp = timestamp()
#   }

#   lifecycle {
#     # Prevent destruction until all referencing resources are gone
#     create_before_destroy = false
#   }

#   depends_on = [azurerm_disk_encryption_set.shared_des]
# }

# # ✅ UPDATE: Force DES cleanup after access policy is handled
# resource "null_resource" "force_des_cleanup" {
#   count = var.disk_encryption_set_config != null ? 1 : 0

#   triggers = {
#     des_id = azurerm_disk_encryption_set.shared_des[0].id
#     tracker_id = null_resource.des_dependency_tracker[0].id
#     cleanup_id = null_resource.cleanup_des_access_policy[0].id  # ✅ NEW dependency
#   }

#   # Force delete DES if it's still referenced during destroy
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       echo "🔒 Waiting for VM cleanup before DES removal..."
#       # Wait extra time for VM disk references to clear
#       sleep 180
      
#       echo "Checking for remaining VM disk references..."
#       DES_ID="${self.triggers.des_id}"
#       DES_NAME=$(echo "$DES_ID" | sed 's|.*/||')
#       DES_RG=$(echo "$DES_ID" | sed 's|.*resourceGroups/||' | sed 's|/providers.*||')
      
#       # Check for any VMs still using this DES
#       USING_VMS=$(az vm list --query "[?storageProfile.osDisk.managedDisk.diskEncryptionSet.id=='$DES_ID'].name" -o tsv 2>/dev/null || true)
#       if [ -n "$USING_VMS" ]; then
#         echo "⚠️ VMs still using DES: $USING_VMS"
#         echo "Waiting additional 120 seconds for VM cleanup..."
#         sleep 120
#       fi
      
#       # Check for any managed disks still using this DES
#       USING_DISKS=$(az disk list --query "[?encryption.diskEncryptionSetId=='$DES_ID'].name" -o tsv 2>/dev/null || true)
#       if [ -n "$USING_DISKS" ]; then
#         echo "⚠️ Disks still using DES: $USING_DISKS"
#         echo "Waiting additional 120 seconds for disk cleanup..."
#         sleep 120
#       fi
      
#       echo "Attempting DES cleanup: $DES_NAME"
#       # Try to delete DES manually if needed
#       az disk-encryption-set delete --name "$DES_NAME" --resource-group "$DES_RG" --yes --no-wait 2>/dev/null && echo "✅ DES deletion initiated" || echo "⚠️ DES deletion failed (expected if already deleted)"
#     EOT
#   }

#   depends_on = [
#     azurerm_disk_encryption_set.shared_des,
#     null_resource.des_dependency_tracker,
#     null_resource.cleanup_des_access_policy  # ✅ NEW dependency
#   ]
# }

# # ✅ CRITICAL: Pre-apply Key Vault access enabler
# resource "null_resource" "pre_apply_kv_access_enabler" {
#   # Trigger on every apply to ensure access is enabled
#   triggers = {
#     kv_name = substr(regex("[a-zA-Z0-9-]+", replace(replace("${var.key_vault_config.name}-${var.random_suffix}", "_", "-"), "[^a-zA-Z0-9-]", "")), 0, 24)
#     resource_group = var.resource_group_name
#     timestamp = timestamp()
#   }

#   # Force enable public access before any Key Vault operations
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "🔓 Ensuring Key Vault public access is enabled before apply..."
#       az keyvault update --name ${self.triggers.kv_name} --resource-group ${self.triggers.resource_group} --public-network-access Enabled --default-action Allow 2>/dev/null || echo "Key Vault may not exist yet"
#       echo "✅ Key Vault access enabler completed"
#     EOT
#   }
# }

# ✅ CRITICAL: Key Vault with proper configuration for CMK
resource "azurerm_key_vault" "kv" {
  name                            = substr(regex("[a-zA-Z0-9-]+", replace(replace("${var.key_vault_config.name}-${var.random_suffix}", "_", "-"), "[^a-zA-Z0-9-]", "")), 0, 24)  # ✅ Ensure valid KV name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  sku_name                        = var.key_vault_config.sku_name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption     = var.key_vault_config.enabled_for_disk_encryption
  enabled_for_deployment          = lookup(var.key_vault_config, "enabled_for_deployment", false)
  enabled_for_template_deployment = var.key_vault_config.enabled_for_template_deployment
  enable_rbac_authorization       = var.key_vault_config.enable_rbac_authorization
  soft_delete_retention_days      = var.key_vault_config.soft_delete_retention_days
  purge_protection_enabled        = var.key_vault_config.purge_protection_enabled

  # ✅ CRITICAL: Force public access for smooth destroy operations
  public_network_access_enabled = true

  tags = var.key_vault_config.tags

  # ✅ CRITICAL: Ensure unrestricted access for Terraform operations
  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
    # ✅ Allow all IP ranges to prevent destroy issues
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  # ✅ ENSURE: Access policies include current user and any initial policies
  dynamic "access_policy" {
    for_each = var.key_vault_config.access_policies
    content {
      tenant_id               = access_policy.value.tenant_id
      object_id               = access_policy.value.object_id
      application_id          = lookup(access_policy.value, "application_id", null)
      key_permissions         = access_policy.value.key_permissions
      secret_permissions      = access_policy.value.secret_permissions
      certificate_permissions = access_policy.value.certificate_permissions
      storage_permissions     = lookup(access_policy.value, "storage_permissions", null)
    }
  }

  # ✅ AUTOMATIC: Add current user access policy when RBAC is disabled
  dynamic "access_policy" {
    for_each = var.key_vault_config.enable_rbac_authorization == false ? [1] : []
    content {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = data.azurerm_client_config.current.object_id
      
      key_permissions = [
        "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", 
        "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", 
        "Update", "Verify", "WrapKey", "Release", "Rotate", "GetRotationPolicy", "SetRotationPolicy"
      ]
      
      secret_permissions = [
        "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
      ]
      
      certificate_permissions = [
        "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", 
        "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", 
        "Purge", "Recover", "Restore", "SetIssuers", "Update"
      ]
    }
  }

  lifecycle {
    create_before_destroy = false
    prevent_destroy       = false
    # ✅ REMOVED: Don't ignore network_acls - let Terraform enforce public access
  }
}



# ✅ CRITICAL: Encryption Keys for Storage CMK
resource "azurerm_key_vault_key" "keys" {
  for_each = var.encryption_keys

  name         = each.value.name
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = each.value.key_type
  key_size     = lookup(each.value, "key_size", null)
  curve        = lookup(each.value, "curve", null)
  key_opts     = each.value.key_opts
  tags         = lookup(each.value, "tags", null)

  # ✅ TEMPORARY FIX: Remove rotation policy due to insufficient permissions
  # Can be added later when SetRotationPolicy permission is available
  # rotation_policy {
  #   automatic {
  #     time_before_expiry = "P30D"
  #   }
  #   expire_after         = "P90D"
  #   notify_before_expiry = "P29D"
  # }

  lifecycle {
    prevent_destroy = false
    # ✅ CRITICAL: Ignore rotation policy changes to prevent destroy issues
    ignore_changes = [rotation_policy]
  }

  depends_on = [
    azurerm_key_vault.kv,
    null_resource.pre_apply_kv_access_enabler
  ]
}

# Key Vault Secrets
resource "azurerm_key_vault_secret" "secrets" {
  for_each = var.key_vault_secrets

  name         = each.value.name
  value        = each.value.value
  key_vault_id = azurerm_key_vault.kv.id
  content_type = lookup(each.value, "content_type", null)
  tags         = lookup(each.value, "tags", null)

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    azurerm_key_vault.kv
    #null_resource.pre_apply_kv_access_enabler
  ]
}

# ✅ CRITICAL: Ensure Key Vault public access and permissions during destroy
# resource "null_resource" "kv_public_access_enforcer" {
#   # Trigger when Key Vault changes or during destroy
#   triggers = {
#     key_vault_name = azurerm_key_vault.kv.name
#     resource_group = var.resource_group_name
#     tenant_id = data.azurerm_client_config.current.tenant_id
#   }

#   # Enable public access and full permissions before any destroy operations
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       set -e
#       echo "🔓 Enabling Key Vault access for destroy operations..."
      
#       # Function to retry command
#       retry_cmd() {
#         local cmd="$1"
#         local max_attempts=3
#         local attempt=1
        
#         while [ $attempt -le $max_attempts ]; do
#           if eval "$cmd"; then
#             return 0
#           fi
#           attempt=$((attempt + 1))
#           [ $attempt -le $max_attempts ] && sleep 5
#         done
#         return 1
#       }
      
#       # Enable public access
#       retry_cmd "az keyvault update --name '${self.triggers.key_vault_name}' --resource-group '${self.triggers.resource_group}' --public-network-access Enabled --default-action Allow" || echo "Failed to enable public access"
      
#       # Grant current user ALL permissions for destroy operations
#       CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
#       if [ -n "$CURRENT_USER_ID" ]; then
#         echo "Granting full Key Vault permissions to current user: $CURRENT_USER_ID"
#         retry_cmd "az keyvault set-policy --name '${self.triggers.key_vault_name}' --object-id '$CURRENT_USER_ID' --key-permissions backup create decrypt delete encrypt get import list purge recover restore sign unwrapKey update verify wrapKey release rotate getRotationPolicy setRotationPolicy --secret-permissions backup delete get list purge recover restore set --certificate-permissions backup create delete deleteIssuers get getIssuers import list listIssuers manageContacts manageIssuers purge recover restore setIssuers update" || echo "Failed to set full user permissions"
#       fi
      
#       echo "✅ Key Vault access setup completed"
#     EOT
#   }

#   depends_on = [azurerm_key_vault.kv]
# }

# Note: Key Vault cleanup handled via lifecycle rules above

# ✅ FIXED: Azure Firewall Public IP
resource "azurerm_public_ip" "fw_pip" {
  count = var.firewall_config != null ? var.firewall_config.public_ip_count : 0

  name                = "${var.firewall_config.name}-pip-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = lookup(var.firewall_config, "tags", {})
}

# ✅ FIXED: Azure Firewall Policy
resource "azurerm_firewall_policy" "fw_policy" {
  count = var.firewall_config != null ? 1 : 0

  name                = "${var.firewall_config.name}-policy"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.firewall_config.sku_tier

  tags = lookup(var.firewall_config, "tags", {})
}

# ✅ FIXED: Firewall Policy Rule Collection Group with correct syntax
resource "azurerm_firewall_policy_rule_collection_group" "fw_policy_rules" {
  count = var.firewall_config != null && (length(var.firewall_policy_rules) > 0 || length(var.firewall_network_policy_rules) > 0) ? 1 : 0

  name               = "${var.firewall_config.name}-policy-rules"
  firewall_policy_id = azurerm_firewall_policy.fw_policy[0].id
  priority           = 100

  # Application Rule Collections (Http, Https, Mssql + FQDNs only)
  dynamic "application_rule_collection" {
    for_each = var.firewall_policy_rules
    content {
      name     = application_rule_collection.value.name
      priority = application_rule_collection.value.priority
      action   = application_rule_collection.value.action

      dynamic "rule" {
        for_each = application_rule_collection.value.rules
        content {
          name = rule.value.name
          
          dynamic "protocols" {
            for_each = rule.value.protocols
            content {
              type = protocols.value.type
              port = protocols.value.port
            }
          }
          
          source_addresses  = rule.value.source_addresses
          destination_fqdns = rule.value.destination_fqdns
        }
      }
    }
  }

  # ✅ FIXED: Use direct variable reference instead of lookup
  dynamic "network_rule_collection" {
    for_each = var.firewall_network_policy_rules
    content {
      name     = network_rule_collection.value.name
      priority = network_rule_collection.value.priority
      action   = network_rule_collection.value.action

      dynamic "rule" {
        for_each = network_rule_collection.value.rules
        content {
          name                  = rule.value.name
          source_addresses      = rule.value.source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_ports     = rule.value.destination_ports
          protocols             = rule.value.protocols
        }
      }
    }
  }

  depends_on = [azurerm_firewall_policy.fw_policy]
}

# ✅ CRITICAL: Azure Firewall with proper dependencies
resource "azurerm_firewall" "fw" {
  count = var.firewall_config != null ? 1 : 0

  name                = var.firewall_config.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.firewall_config.sku_name
  sku_tier            = var.firewall_config.sku_tier
  firewall_policy_id  = azurerm_firewall_policy.fw_policy[0].id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_ids[var.firewall_config.firewall_subnet_key_ref]
    public_ip_address_id = azurerm_public_ip.fw_pip[0].id
  }

  tags = lookup(var.firewall_config, "tags", {})

  depends_on = [
    azurerm_firewall_policy.fw_policy,
    azurerm_public_ip.fw_pip
  ]
}

# Application Gateway Public IP
resource "azurerm_public_ip" "app_gw_pip" {
  count = var.app_gateway_config != null ? 1 : 0

  name                = "${var.app_gateway_config.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = lookup(var.app_gateway_config, "tags", {})
}

# WAF Policy
resource "azurerm_web_application_firewall_policy" "app_gw_waf_policy" {
  count = var.waf_policy_config != null ? 1 : 0

  name                = var.waf_policy_config.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.waf_policy_config.tags

  # Add your WAF policy configuration here
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

# ✅ ADD: Data source for subnet lookup as fallback
data "azurerm_subnet" "app_gateway_subnet" {
  count = var.app_gateway_config != null ? 1 : 0
  
  name                 = "snet-hub-agw-POCpub-1"  # The actual subnet name
  virtual_network_name = "vnet-hub-POCpub-1"     # The VNet name
  resource_group_name  = var.network_resource_group_name
}

# Application Gateway with fallback subnet lookup
resource "azurerm_application_gateway" "app_gw" {
  count = var.app_gateway_config != null ? 1 : 0

  name                = var.app_gateway_config.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = lookup(var.app_gateway_config, "tags", null)

  sku {
    name     = var.app_gateway_config.sku.name
    tier     = var.app_gateway_config.sku.tier
    capacity = lookup(var.app_gateway_config.sku, "capacity", 2)
  }

  # ✅ Gateway IP Configuration (this is working)
  dynamic "gateway_ip_configuration" {
    for_each = var.app_gateway_config.gateway_ip_configuration
    content {
      name      = gateway_ip_configuration.value.name
      subnet_id = var.subnet_ids[gateway_ip_configuration.value.subnet_id]  # Use variable lookup
    }
  }

  # ✅ Public IP Configuration
  frontend_ip_configuration {
    name                 = var.app_gateway_config.frontend_ip_configuration[0].name
    public_ip_address_id = azurerm_public_ip.app_gw_pip[0].id
  }



  dynamic "frontend_port" {
    for_each = var.app_gateway_config.frontend_port
    content {
      name = frontend_port.value.name
      port = frontend_port.value.port
    }
  }

  dynamic "backend_address_pool" {
    for_each = var.app_gateway_config.backend_address_pool
    content {
      name         = backend_address_pool.value.name
      fqdns        = lookup(backend_address_pool.value, "fqdns", [])
      ip_addresses = lookup(backend_address_pool.value, "ip_addresses", [])
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.app_gateway_config.backend_http_settings
    content {
      name                                = backend_http_settings.value.name
      cookie_based_affinity               = backend_http_settings.value.cookie_based_affinity
      port                                = backend_http_settings.value.port
      protocol                            = backend_http_settings.value.protocol
      request_timeout                     = backend_http_settings.value.request_timeout
      probe_name                          = lookup(backend_http_settings.value, "probe_name", null)
      host_name                           = lookup(backend_http_settings.value, "host_name", null)
      path                                = lookup(backend_http_settings.value, "path", "")
      pick_host_name_from_backend_address = lookup(backend_http_settings.value, "pick_host_name_from_backend_address", false)
    }
  }

  dynamic "http_listener" {
    for_each = var.app_gateway_config.http_listener
    content {
      name                           = http_listener.value.name
      frontend_ip_configuration_name = http_listener.value.frontend_ip_configuration_name
      frontend_port_name             = http_listener.value.frontend_port_name
      protocol                       = http_listener.value.protocol
    }
  }



  dynamic "request_routing_rule" {
    for_each = var.app_gateway_config.request_routing_rule
    content {
      name                       = request_routing_rule.value.name
      rule_type                  = request_routing_rule.value.rule_type
      http_listener_name         = request_routing_rule.value.http_listener_name
      backend_address_pool_name  = request_routing_rule.value.backend_address_pool_name
      backend_http_settings_name = request_routing_rule.value.backend_http_settings_name
      priority                   = request_routing_rule.value.priority
    }
  }




  dynamic "probe" {
    for_each = var.app_gateway_config != null && var.app_gateway_config.probe != null ? var.app_gateway_config.probe : []
    content {
      name                                      = probe.value.name
      protocol                                  = probe.value.protocol
      path                                      = probe.value.path
      interval                                  = probe.value.interval
      timeout                                   = probe.value.timeout
      unhealthy_threshold                       = probe.value.unhealthy_threshold
      host                                      = lookup(probe.value, "host", null)
      pick_host_name_from_backend_http_settings = lookup(probe.value, "pick_host_name_from_backend_http_settings", null)

      dynamic "match" {
        for_each = lookup(probe.value, "match", null) != null ? [probe.value.match] : []
        content {
          body        = lookup(match.value, "body", "")
          status_code = lookup(match.value, "status_code", ["200"])
        }
      }
    }
  }

  dynamic "waf_configuration" {
    for_each = lookup(var.app_gateway_config, "waf_configuration", null) != null ? [var.app_gateway_config.waf_configuration] : []
    content {
      enabled                  = waf_configuration.value.enabled
      firewall_mode            = waf_configuration.value.firewall_mode
      rule_set_type            = waf_configuration.value.rule_set_type
      rule_set_version         = waf_configuration.value.rule_set_version
      request_body_check       = lookup(waf_configuration.value, "request_body_check", true)
      max_request_body_size_kb = lookup(waf_configuration.value, "max_request_body_size_kb", 128)
      file_upload_limit_mb     = lookup(waf_configuration.value, "file_upload_limit_mb", 100)
    }
  }

  depends_on = [azurerm_public_ip.app_gw_pip]
}

# Application Gateway Managed Identity
resource "azurerm_user_assigned_identity" "app_gateway_identity" {
  count = var.app_gateway_config != null ? 1 : 0

  name                = "id-appgateway-${var.app_gateway_config.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = lookup(var.app_gateway_config, "tags", null)
}
