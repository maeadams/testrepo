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

# ✅ DATA SOURCE: Required for access policy tenant_id
data "azurerm_client_config" "current" {}

# ✅ REMOVE: Delete this resource since we'll use the passed random_suffix
# resource "random_string" "unique" {
#   length  = 6
#   upper   = false
#   special = false
# }

# SQL Managed Instance
resource "azurerm_mssql_managed_instance" "sql_mi" {
  name                         = "${var.mi_settings.name_prefix}-${var.random_suffix}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  subnet_id                    = var.subnet_ids[var.mi_subnet_key]
  sku_name                     = var.mi_settings.sku_name
  vcores                       = var.mi_settings.vcores
  storage_size_in_gb           = var.mi_settings.storage_size_in_gb
  administrator_login          = var.mi_settings.administrator_login
  administrator_login_password = var.mi_settings.administrator_login_password
  public_data_endpoint_enabled = var.mi_settings.public_data_endpoint_enabled
  collation                    = var.mi_settings.collation
  license_type                 = var.mi_settings.license_type
  proxy_override               = var.mi_settings.proxy_override
  timezone_id                  = var.mi_settings.timezone_id
  minimum_tls_version          = lookup(var.mi_settings, "minimal_tls_version", "1.2")

  # ✅ ENABLE: System-assigned identity for CMK
  identity {
    type = "SystemAssigned"
  }

  tags = var.mi_settings.tags
}

# ✅ ENHANCED: Multiple RBAC role assignments for SQL MI (RBAC-enabled Key Vault)
##resource "azurerm_role_assignment" "sql_mi_key_vault_crypto_user" {
#  count = lookup(var.mi_settings, "transparent_data_encryption_key_vault_key_id", null) != null ? 1 : 0
#
#  scope                = var.key_vault_id
#  role_definition_name = "Key Vault Crypto Service Encryption User"
#  principal_id         = azurerm_mssql_managed_instance.sql_mi.identity[0].principal_id
#
#  depends_on = [azurerm_mssql_managed_instance.sql_mi]
#}

# ✅ ADDITIONAL: Key Vault Reader role for SQL MI identity
##resource "azurerm_role_assignment" "sql_mi_key_vault_reader" {
#  count = lookup(var.mi_settings, "transparent_data_encryption_key_vault_key_id", null) != null ? 1 : 0
#
#  scope                = var.key_vault_id
#  role_definition_name = "Key Vault Reader"
#  principal_id         = azurerm_mssql_managed_instance.sql_mi.identity[0].principal_id
#
#  depends_on = [azurerm_mssql_managed_instance.sql_mi]
#}

# ✅ ADDITIONAL: Key Vault Crypto Officer for SQL MI
##resource "azurerm_role_assignment" "sql_mi_key_vault_crypto_officer" {
#  count = lookup(var.mi_settings, "transparent_data_encryption_key_vault_key_id", null) != null ? 1 : 0
#
#  scope                = var.key_vault_id
#  role_definition_name = "Key Vault Crypto Officer"
#  principal_id         = azurerm_mssql_managed_instance.sql_mi.identity[0].principal_id
#
#  depends_on = [azurerm_mssql_managed_instance.sql_mi]
#}

# ✅ CRITICAL: Access Policy for SQL MI Identity (must be before TDE is configured)
resource "azurerm_key_vault_access_policy" "sql_mi_access_policy" {
  count = lookup(var.mi_settings, "transparent_data_encryption_key_vault_key_id", null) != null ? 1 : 0

  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_mssql_managed_instance.sql_mi.identity[0].principal_id

  key_permissions = [
    "Get", "UnwrapKey", "WrapKey"
  ]

  depends_on = [azurerm_mssql_managed_instance.sql_mi]
}

# ✅ ENHANCED: Wait for access policy before TDE configuration
resource "time_sleep" "wait_for_mi_access_policy" {
  count = lookup(var.mi_settings, "transparent_data_encryption_key_vault_key_id", null) != null ? 1 : 0

  depends_on = [
    azurerm_mssql_managed_instance.sql_mi,
    azurerm_key_vault_access_policy.sql_mi_access_policy
  ]
  create_duration = "60s" # ✅ Wait for access policy propagation
}

# ✅ ADD: TDE with CMK
resource "azurerm_mssql_managed_instance_transparent_data_encryption" "main" {
  count = lookup(var.mi_settings, "transparent_data_encryption_key_vault_key_id", null) != null ? 1 : 0

  managed_instance_id = azurerm_mssql_managed_instance.sql_mi.id
  key_vault_key_id    = var.key_vault_key_ids[var.mi_settings.transparent_data_encryption_key_vault_key_id]

  depends_on = [
    time_sleep.wait_for_mi_access_policy
  ]
}

# ✅ REMOVED: Private DNS Zone - using existing one from network module to avoid conflict
# resource "azurerm_private_dns_zone" "sql_mi_pdnsz" {
#   for_each = var.private_endpoint_config != null ? var.private_endpoint_config : {}
#   name                = each.value.private_dns_zone_name
#   resource_group_name = var.resource_group_name
#   tags                = var.mi_settings.tags
# }

# ✅ ADD: Data source to reference existing private DNS zone (conditional)
data "azurerm_private_dns_zone" "sql_mi_pdnsz" {
  for_each = var.private_endpoint_config != null ? var.private_endpoint_config : {}

  name                = each.value.private_dns_zone_name
  resource_group_name = "network-hub" # ✅ FIXED: Use correct RG name
}

# ✅ REMOVED: VNet Link - already exists from network module to avoid conflict
# resource "azurerm_private_dns_zone_virtual_network_link" "sql_mi_pdnsz_vnet_link" {
#   for_each = var.private_endpoint_config != null ? var.private_endpoint_config : {}
#   name                  = "${each.value.private_dns_zone_name}-link-db"
#   resource_group_name   = var.resource_group_name
#   private_dns_zone_name = data.azurerm_private_dns_zone.sql_mi_pdnsz[each.key].name
#   virtual_network_id    = var.vnet_id
#   registration_enabled  = false
# }

# ✅ REMOVED: Private endpoint - SQL MI delegation provides private connectivity
# Cannot create private endpoints on delegated subnets
# resource "azurerm_private_endpoint" "sql_mi_pe" {
#   for_each = var.private_endpoint_config != null ? var.private_endpoint_config : {}
#
#   name                = each.value.name
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   subnet_id           = var.subnet_ids[each.value.subnet_id]
#
#   private_service_connection {
#     name                           = "${each.value.name}-connection"
#     private_connection_resource_id = azurerm_mssql_managed_instance.sql_mi.id
#     subresource_names              = ["managedInstance"]
#     is_manual_connection           = false
#   }
#
#   private_dns_zone_group {
#     name                 = "dns-zone-group"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.sql_mi_pdnsz[each.key].id]
#   }
#
#   tags = { "Environment" = "POC", "Purpose" = "SQLMIPrivateAccess" }
#
#   depends_on = [azurerm_mssql_managed_instance.sql_mi]
# }

# ✅ REMOVED: Private DNS A Record - not needed with delegation
# SQL MI delegation automatically handles DNS resolution within the VNet
# resource "azurerm_private_dns_a_record" "sql_mi_dns" {
#   for_each = var.private_endpoint_config != null ? var.private_endpoint_config : {}
#
#   name                = azurerm_mssql_managed_instance.sql_mi.name
#   zone_name           = data.azurerm_private_dns_zone.sql_mi_pdnsz[each.key].name
#   resource_group_name = var.resource_group_name
#   ttl                 = 300
#   records             = [azurerm_private_endpoint.sql_mi_pe[each.key].private_service_connection[0].private_ip_address]
#
#   depends_on = [azurerm_private_endpoint.sql_mi_pe, data.azurerm_private_dns_zone.sql_mi_pdnsz]
# }
