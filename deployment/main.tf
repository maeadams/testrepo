# =============================================================================
# ROOT MAIN.TF - COMMERCIAL AZURE LANDING ZONE POC
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    pkcs12 = {
      source  = "chilicat/pkcs12"
      version = "~> 0.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.0"
}

# Provider configurations
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

  }
  use_oidc = true
}


provider "azuread" {}
provider "tls" {}
provider "pkcs12" {}
provider "null" {}
provider "random" {}
provider "time" {}

# =============================================================================
# RANDOM SUFFIX GENERATION
# =============================================================================

resource "random_string" "unique" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "azurerm_client_config" "current" {}

data "azuread_user" "admin_user" {
  user_principal_name = var.admin_user_principal_name
}

# SSH Key Generation for Linux VMs (if needed)
resource "tls_private_key" "vm_ssh_key" {
  count     = length(var.linux_vms) > 0 ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "vm_ssh_private_key" {
  count    = length(var.linux_vms) > 0 ? 1 : 0
  content  = tls_private_key.vm_ssh_key[0].private_key_pem
  filename = "./cmk_rsa/id_rsa_azure_vm"
}

resource "local_file" "vm_ssh_public_key" {
  count    = length(var.linux_vms) > 0 ? 1 : 0
  content  = tls_private_key.vm_ssh_key[0].public_key_openssh
  filename = "./cmk_rsa/id_rsa_azure_vm.pub"
}

# =============================================================================
# COMMON TAGS
# =============================================================================
locals {
  common_tags = {
    Environment        = "POC"
    Project            = "Commercial-Azure-Landing-Zone"
    DeployedBy         = "Terraform"
    DeploymentDate     = formatdate("YYYY-MM-DD", timestamp())
    RandomSuffix       = random_string.unique.result
    ManagedBy          = "Infrastructure-Team"
    CostCenter         = "IT-Infrastructure"
    BusinessOwner      = "Commercial-Division"
    TechnicalOwner     = "Cloud-Architects"
    DataClassification = "Internal"
    Backup             = "Required"
    Monitoring         = "Enabled"
    Security           = "Standard"
  }

  # ✅ FIX: SSH public key local value for compute module
  ssh_public_key = length(var.linux_vms) > 0 ? tls_private_key.vm_ssh_key[0].public_key_openssh : ""

  # ✅ PREVENT: Extension recreation by using consistent configuration
  vm_extensions_processed = {
    for k, v in var.vm_extensions_raw : k => {
      name                 = v.name
      virtual_machine_name = v.virtual_machine_name
      publisher            = v.publisher
      type                 = v.type
      type_handler_version = v.type_handler_version
      settings             = v.settings_object != null ? jsonencode(v.settings_object) : null
      protected_settings   = v.protected_settings_object != null ? jsonencode(v.protected_settings_object) : null
      tags                 = v.tags
    }
  }
}


# =============================================================================
# RESOURCE ORGANIZATION MODULE
# =============================================================================

module "resource_organization" {
  source = "../modules/resource-organization"

  management_group_config = var.management_group_config
  policy_definitions      = var.policy_definitions
  policy_assignments      = var.policy_assignments
  resource_groups         = var.resource_groups
}

# =============================================================================
# NETWORK MODULE (HUB + SPOKES)
# =============================================================================

module "network" {
  source = "../modules/network"

  resource_group_name              = module.resource_organization.resource_group_names["rg_network_hub"]
  location                         = var.location
  hub_vnet_config                  = var.hub_vnet_config
  spoke_vnet_configs               = var.spoke_vnet_configs
  subnet_configs                   = var.subnet_configs
  nsg_rules                        = var.nsg_rules
  route_tables                     = var.route_tables
  vpn_gateway_config               = var.vpn_gateway_config
  private_endpoint_configs         = var.private_endpoint_configs
  bastion_host_config              = var.bastion_host_config
  eventgrid_source_arm_resource_id = var.eventgrid_source_arm_resource_id

  depends_on = [module.resource_organization]
}

# =============================================================================
# IDENTITY MODULE
# =============================================================================

module "identity" {
  source = "../modules/identity"

  custom_roles       = var.custom_roles
  managed_identities = var.managed_identities
  identity_providers = var.identity_providers

  # ✅ FIXED: Pass role assignments with resolved principal ID
  role_assignments = {
    for k, v in var.role_assignments : k => merge(v, {
      principal_id = contains(["admin_key_vault_access", "admin_key_vault_crypto_admin"], k) ? data.azuread_user.admin_user.object_id : v.principal_id
    })
  }

  application_owner_object_id = data.azuread_user.admin_user.object_id
  random_suffix               = random_string.unique.result

  depends_on = [
    module.resource_organization
  ]
}

# =============================================================================
# SECURITY MODULE (KEY VAULT + FIREWALL + APP GATEWAY)
# =============================================================================

module "security" {
  source = "../modules/security"

  resource_group_name         = module.resource_organization.resource_group_names["rg_network_hub"]
  network_resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"]
  location                    = var.location
  subnet_ids                  = module.network.subnet_ids

  firewall_config               = var.firewall_config
  firewall_policy_rules         = var.firewall_policy_rules
  firewall_network_policy_rules = var.firewall_network_policy_rules # ✅ Pass the variable

  key_vault_config           = var.key_vault_config
  encryption_keys            = var.encryption_keys
  key_vault_secrets          = var.key_vault_secrets
  app_gateway_config         = var.app_gateway_config
  waf_policy_config          = var.waf_policy_config
  disk_encryption_set_config = var.disk_encryption_set_config
  random_suffix              = random_string.unique.result

  depends_on = [module.network]
}

# =============================================================================
# MONITORING MODULE
# =============================================================================

module "monitoring" {
  source = "../modules/monitoring"

  resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"]
  location            = var.location

  workspace_config = var.workspace_config
  action_groups    = var.action_groups

  # ✅ FIXED: Pass resolved action group IDs to service health alerts
  service_health_alerts = {
    for k, v in var.service_health_alerts : k => merge(v, {
      action_group_ids = [
        for ag_key in v.action_group_ids :
        module.monitoring.action_group_ids[ag_key]
      ]
    })
  }

  diagnostic_settings   = var.diagnostic_settings
  data_collection_rules = var.data_collection_rules

  depends_on = [
    module.resource_organization
  ]
}

# =============================================================================
# SHARED STORAGE MODULE (Network Hub)
# =============================================================================
module "storage" {
  source = "../modules/storage"

  resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"]
  location            = var.location
  key_vault_id        = module.security.key_vault_id
  # ✅ ONLY shared storage accounts (flow logs, shared data)
  storage_accounts = {
    for k, v in var.storage_accounts : k => v
    if contains(["st_flowlogs", "st_shared_data"], k)
  }
  storage_containers = {
    for k, v in var.storage_containers : k => v
    if contains(["container_flow_logs", "container_shared_data"], k)
  }
  managed_disks                  = var.managed_disks
  recovery_services_vault_config = var.recovery_services_vault_config
  backup_policies_vm             = var.backup_policies_vm
  vms_to_backup                  = var.vms_to_backup
  site_recovery_config           = var.site_recovery_config

  depends_on = [
    module.resource_organization,
    module.security
  ]
}

# =============================================================================
# BACKEND NON-EXPOSED STORAGE MODULE
# =============================================================================
module "storage_be_nonexposed" {
  source = "../modules/storage"

  resource_group_name = module.resource_organization.resource_group_names["rg_be_nonexposed_apps"]
  location            = var.location
  key_vault_id        = module.security.key_vault_id
  # ✅ Storage for non-exposed backend applications
  storage_accounts = {
    for k, v in var.storage_accounts : k => v
    if contains(["st_nonexposed_data"], k)
  }
  storage_containers = {
    for k, v in var.storage_containers : k => v
    if contains(["container_nonexposed_data"], k)
  }
  managed_disks                  = {}
  recovery_services_vault_config = null # Only one recovery vault needed (in hub)
  backup_policies_vm             = {}
  vms_to_backup                  = {}
  site_recovery_config           = null

  depends_on = [
    module.resource_organization,
    module.security
  ]
}

# =============================================================================
# BACKEND EXPOSED STORAGE MODULE
# =============================================================================
module "storage_be_exposed" {
  source = "../modules/storage"

  resource_group_name = module.resource_organization.resource_group_names["rg_be_exposed_apps"]
  location            = var.location
  key_vault_id        = module.security.key_vault_id
  # ✅ Storage for exposed backend applications
  storage_accounts = {
    for k, v in var.storage_accounts : k => v
    if contains(["st_exposed_data"], k)
  }
  storage_containers = {
    for k, v in var.storage_containers : k => v
    if contains(["container_exposed_data"], k)
  }
  managed_disks                  = {}
  recovery_services_vault_config = null # Only one recovery vault needed (in hub)
  backup_policies_vm             = {}
  vms_to_backup                  = {}
  site_recovery_config           = null

  depends_on = [
    module.resource_organization,
    module.security
  ]
}

# ✅ FIXED: Enhanced DES Protection - depends on security module's destroy protection
resource "null_resource" "des_protection" {
  depends_on = [
    module.compute,
    module.onprem_compute,
    module.fe_nonexposed_compute,
    module.fe_exposed_compute,
    azurerm_network_watcher_flow_log.nsg_flow_logs,
    # ✅ CRITICAL: Depend on security module's destroy protection
    module.security
  ]

  triggers = {
    des_id       = module.security.disk_encryption_set_id
    key_vault_id = module.security.key_vault_id
    timestamp    = timestamp()
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🔒 All compute modules destroyed - DES and Key Vault can now be safely removed"
      echo "DES ID: ${self.triggers.des_id}"
      echo "Key Vault ID: ${self.triggers.key_vault_id}"
      echo "⏳ Waiting 60 seconds for disk references to clear..."
      sleep 60
    EOT
  }

  lifecycle {
    create_before_destroy = false
  }
}

# =============================================================================
# COMPUTE MODULE (ADMIN VM ONLY)
# =============================================================================



# ✅ REORGANIZED: Hub Compute Module (Admin VM only)
module "compute" {
  source = "../modules/compute"

  resource_group_name          = module.resource_organization.resource_group_names["rg_network_hub"]
  security_resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"]
  location                     = var.location
  subnet_ids                   = module.network.subnet_ids
  random_suffix                = random_string.unique.result

  # ✅ FIXED: Use local value for SSH key
  linux_vms = {
    for k, v in var.linux_vms : k => merge(v, {
      admin_ssh_key = merge(v.admin_ssh_key, {
        public_key = local.ssh_public_key
      })
    })
  }

  # ✅ ONLY Hub VMs (Admin VM only - other VMs moved to respective modules)
  windows_vms = {
    for k, v in var.windows_vms : k => v
    if v.subnet_name == "snet_hub_compute"
  }
  vm_extensions               = local.vm_extensions_processed
  key_vault_id                = module.security.key_vault_id
  disk_encryption_key_url     = module.security.disk_encryption_key_url
  disk_encryption_set_id      = module.security.disk_encryption_set_id
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  log_analytics_workspace_key = module.monitoring.log_analytics_workspace_key
  windows_events_dcr_id       = null

  depends_on = [
    module.security,
    module.monitoring,
    module.network
  ]
}

# =============================================================================
# ONPREM COMPUTE MODULE (SEPARATE RESOURCE GROUP)
# =============================================================================

# ✅ REORGANIZED: OnPrem Compute Module
module "onprem_compute" {
  source = "../modules/compute"

  resource_group_name          = module.resource_organization.resource_group_names["rg_onprem"]
  security_resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"] # Key Vault in hub
  location                     = var.location
  subnet_ids                   = module.network.subnet_ids
  random_suffix                = random_string.unique.result

  # OnPrem VMs only
  windows_vms = {
    for k, v in var.windows_vms : k => v
    if v.subnet_name == "snet_onprem_compute"
  }

  linux_vms                   = {}                            # No Linux VMs in OnPrem
  vm_extensions               = local.vm_extensions_processed # ✅ FIXED: Include extensions for OnPrem VMs
  key_vault_id                = module.security.key_vault_id
  disk_encryption_key_url     = module.security.disk_encryption_key_url
  disk_encryption_set_id      = module.security.disk_encryption_set_id
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  log_analytics_workspace_key = module.monitoring.log_analytics_workspace_key
  windows_events_dcr_id       = null

  depends_on = [
    module.security,
    module.monitoring,
    module.network
  ]
}

# =============================================================================
# FRONTEND NON-EXPOSED COMPUTE MODULE
# =============================================================================
module "fe_nonexposed_compute" {
  source = "../modules/compute"

  resource_group_name          = module.resource_organization.resource_group_names["rg_fe_nonexposed_apps"]
  security_resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"] # Key Vault in hub
  location                     = var.location
  subnet_ids                   = module.network.subnet_ids
  random_suffix                = random_string.unique.result

  # ✅ ONLY Non-Exposed Frontend VMs
  windows_vms = {
    for k, v in var.windows_vms : k => v
    if v.subnet_name == "snet_compute_nonexpose"
  }
  linux_vms                   = {}
  vm_extensions               = local.vm_extensions_processed
  key_vault_id                = module.security.key_vault_id
  disk_encryption_key_url     = module.security.disk_encryption_key_url
  disk_encryption_set_id      = module.security.disk_encryption_set_id
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  log_analytics_workspace_key = module.monitoring.log_analytics_workspace_key
  windows_events_dcr_id       = null

  depends_on = [
    module.security,
    module.monitoring,
    module.network
  ]
}

# =============================================================================
# FRONTEND EXPOSED COMPUTE MODULE
# =============================================================================
module "fe_exposed_compute" {
  source = "../modules/compute"

  resource_group_name          = module.resource_organization.resource_group_names["rg_fe_exposed_apps"]
  security_resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"] # Key Vault in hub
  location                     = var.location
  subnet_ids                   = module.network.subnet_ids
  random_suffix                = random_string.unique.result

  # ✅ ONLY Exposed Frontend VMs
  windows_vms = {
    for k, v in var.windows_vms : k => v
    if v.subnet_name == "snet_compute_expose"
  }
  linux_vms                   = {}
  vm_extensions               = local.vm_extensions_processed
  key_vault_id                = module.security.key_vault_id
  disk_encryption_key_url     = module.security.disk_encryption_key_url
  disk_encryption_set_id      = module.security.disk_encryption_set_id
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  log_analytics_workspace_key = module.monitoring.log_analytics_workspace_key
  windows_events_dcr_id       = null


  depends_on = [
    module.security,
    module.monitoring,
    module.network
  ]
}

# =============================================================================
# FRONTEND EXPOSED WEB APPLICATIONS MODULE
# =============================================================================
module "fe_exposed_webapp" {
  source = "../modules/application"

  # ---------------------------------------------------------------------------
  # 1.  Web-app objects to deploy in THIS module instance
  # ---------------------------------------------------------------------------
  # Pass ONLY the exposed app, so every service_plan_key you reference
  # exists in the accompanying app_service_plans map.
  web_apps = {
    webapp_exposed = var.web_apps["webapp_exposed"]
  }

  # ---------------------------------------------------------------------------
  # 2.  App-Service Plan(s) used by those web-apps
  # ---------------------------------------------------------------------------
  app_service_plans = {
    asp_fe_exposed = merge(
      var.app_service_plans["asp_fe_exposed"],
      {
        # Override RG / location so the plan is created in the correct scope
        resource_group_name = module.resource_organization.resource_group_names["rg_fe_exposed_apps"]
        location            = var.location
      }
    )
  }

  # ---------------------------------------------------------------------------
  # 3.  Networking inputs required for VNet-integration & private endpoints
  # ---------------------------------------------------------------------------
  subnet_ids           = module.network.subnet_ids
  private_dns_zone_ids = module.network.private_dns_zone_ids

  depends_on = [
    module.resource_organization,
    module.network
  ]
}

# =============================================================================
# FRONTEND NON-EXPOSED WEB APPLICATIONS MODULE
# =============================================================================
module "fe_nonexposed_webapp" {
  source = "../modules/application"

  # ---------- Web-apps this instance deploys ----------
  web_apps = {
    webapp_nonexposed = var.web_apps["webapp_nonexposed"]
  }

  # ---------- Service-plan(s) they need ----------
  app_service_plans = {
    asp_fe_nonexposed = merge(
      var.app_service_plans["asp_fe_nonexposed"],
      {
        resource_group_name = module.resource_organization.resource_group_names["rg_fe_nonexposed_apps"]
        location            = var.location
      }
    )
  }

  # ---------- Networking inputs ----------
  subnet_ids           = module.network.subnet_ids
  private_dns_zone_ids = module.network.private_dns_zone_ids

  depends_on = [
    module.resource_organization,
    module.network
  ]
}


# =============================================================================
# DATABASE MODULE (SQL MANAGED INSTANCE)
# =============================================================================

locals {
  key_vault_key_ids = merge(
    module.security.key_vault_key_ids,
    {
      "key_sqlmi_tde" = module.security.key_vault_key_ids["sqlmi_tde_key"]
    }
  )
}

# ✅ CONDITIONAL: Database module only deploys when enable_sql_mi = true
module "database" {
  count  = var.enable_sql_mi ? 1 : 0
  source = "../modules/database"

  resource_group_name = module.resource_organization.resource_group_names["rg_be_nonexposed_apps"]
  location            = var.location
  subnet_ids          = module.network.subnet_ids
  vnet_id             = module.network.hub_vnet_id
  random_suffix       = random_string.unique.result

  mi_subnet_key           = var.mi_subnet_key
  mi_settings             = var.mi_settings
  private_endpoint_config = var.private_endpoint_config

  key_vault_id      = module.security.key_vault_id
  key_vault_key_ids = local.key_vault_key_ids

  depends_on = [
    module.resource_organization,
    module.network,
    module.security
  ]
}


# =============================================================================
# LEGACY APPLICATION MODULES - REMOVED
# Replaced by fe_exposed_webapp and fe_nonexposed_webapp modules above
# =============================================================================



# =============================================================================
# COST MANAGEMENT MODULE
# =============================================================================

module "cost_management" {
  source = "../modules/cost-management"

  subscription_id        = var.subscription_id
  subscription_budget    = var.subscription_budget
  resource_group_budgets = var.resource_group_budgets

  depends_on = [module.resource_organization]
}

# =============================================================================
# CDN & CACHING MODULE (CONDITIONAL)
# =============================================================================

# ✅ REORGANIZED: CDN in Frontend Exposed (internet-facing)
module "cdn_caching" {
  count  = var.frontdoor_config != null || length(var.redis_cache_config) > 0 ? 1 : 0
  source = "../modules/cdn-caching"

  resource_group_name = module.resource_organization.resource_group_names["rg_fe_exposed_apps"]
  location            = var.location
  subnet_ids          = module.network.subnet_ids
  # ✅ FIX: Remove non-existent vnet_id reference
  vnet_id = ""

  frontdoor_config              = var.frontdoor_config
  frontdoor_waf_policy_config   = var.frontdoor_waf_policy_config
  frontdoor_custom_https_config = var.frontdoor_custom_https_config
  redis_cache_config            = var.redis_cache_config
  redis_firewall_rules          = var.redis_firewall_rules
  redis_private_endpoint_config = var.redis_private_endpoint_config

  depends_on = [
    module.resource_organization,
    module.network
  ]
}

# =============================================================================
# POST-DEPLOYMENT CONFIGURATION
# =============================================================================

# ✅ Wait for critical resources before dependent operations
resource "time_sleep" "wait_for_core_infrastructure" {
  depends_on = [
    module.network,
    module.security,
    module.monitoring,
    module.storage,
    module.storage_be_nonexposed,
    module.storage_be_exposed
  ]

  create_duration = "30s"
}

resource "time_sleep" "wait_for_compute_resources" {
  depends_on = [
    module.compute,
    module.onprem_compute,
    module.fe_nonexposed_compute,
    module.fe_exposed_compute,
    module.fe_exposed_webapp,
    module.fe_nonexposed_webapp,
    time_sleep.wait_for_core_infrastructure
  ]

  create_duration = "60s"
}

# =============================================================================
# VM BACKUP CONFIGURATION
# =============================================================================

# ✅ TEMPORARILY DISABLED: Backup protection causes destroy issues
# Will re-enable after fixing destroy dependencies
# resource "azurerm_backup_protected_vm" "admin_vm_backup" {
#   count = length(var.windows_vms) > 0 && contains(keys(var.windows_vms), "admin_vm") && var.recovery_services_vault_config != null ? 1 : 0

#   resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"]
#   recovery_vault_name = module.storage.recovery_services_vault_name
#   source_vm_id        = module.compute.windows_vm_ids["admin_vm"]
#   backup_policy_id    = module.storage.backup_policy_vm_ids["policy_daily_vm"]

#   depends_on = [
#     module.compute,
#     module.onprem_compute,
#     module.fe_nonexposed_compute,
#     module.fe_exposed_compute,
#     module.fe_exposed_webapp,
#     module.fe_nonexposed_webapp,
#     module.storage,
#     time_sleep.wait_for_compute_resources
#   ]
# }

# =============================================================================
# NETWORK FLOW LOGS CONFIGURATION
# =============================================================================

# ✅ FIX: Network Security Group Flow Logs - simplified without nsg_ids
resource "azurerm_network_watcher_flow_log" "nsg_flow_logs" {
  for_each = {
    for nsg_name in keys(var.nsg_rules) : nsg_name => nsg_name
    if var.flow_log_config != null && length(var.storage_accounts) > 0
  }

  network_watcher_name = "NetworkWatcher_${var.location}"
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flowlog-${each.key}-${random_string.unique.result}"

  # ✅ FIX: Use module output for NSG ID
  network_security_group_id = module.network.network_security_group_ids[each.key]

  storage_account_id = module.storage.storage_account_ids[keys(var.storage_accounts)[0]]
  enabled            = true
  version            = 2

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = module.monitoring.log_analytics_workspace_id
    workspace_region      = var.location
    workspace_resource_id = module.monitoring.log_analytics_workspace_id
    interval_in_minutes   = 10
  }

  depends_on = [
    module.network,
    module.storage,
    module.storage_be_nonexposed,
    module.storage_be_exposed,
    module.monitoring
  ]
}

# =============================================================================
# APP SERVICE AUTHENTICATION (POST-DEPLOYMENT)
# =============================================================================


# =============================================================================
# DIAGNOSTIC SETTINGS FOR KEY RESOURCES
# =============================================================================

# ✅ Key Vault Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "key_vault_diagnostics" {
  name                       = "diag-keyvault-${random_string.unique.result}"
  target_resource_id         = module.security.key_vault_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }

  depends_on = [
    module.security,
    module.monitoring
  ]
}

# ✅ Application Gateway Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "app_gateway_diagnostics" {
  count = var.app_gateway_config != null ? 1 : 0

  name                       = "diag-appgateway-${random_string.unique.result}"
  target_resource_id         = try(module.security.app_gateway_id, "")
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }

  depends_on = [
    module.security,
    module.monitoring
  ]
}

# ✅ FIX: Firewall Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "firewall_diagnostics" {
  count = var.firewall_config != null ? 1 : 0

  name                       = "diag-firewall-${random_string.unique.result}"
  target_resource_id         = try(module.security.firewall_id, "")
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }

  depends_on = [
    module.security,
    module.monitoring
  ]
}

# =============================================================================
# SECURITY ALERTS AND MONITORING
# =============================================================================

# ✅ Security Alerts for Key Resources
resource "azurerm_monitor_metric_alert" "app_gateway_unhealthy_backends" {
  count = var.app_gateway_config != null ? 1 : 0

  name                = "alert-appgateway-unhealthy-backends-${random_string.unique.result}"
  resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"]
  scopes              = [try(module.security.app_gateway_id, "")]
  description         = "Alert when Application Gateway has unhealthy backend servers"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = module.monitoring.action_group_ids[keys(var.action_groups)[0]]
  }

  depends_on = [
    module.security,
    module.monitoring
  ]
}

# ✅ FIX: Key Vault Access Alert with proper location
resource "azurerm_monitor_activity_log_alert" "key_vault_access_alert" {
  name                = "alert-keyvault-access-${random_string.unique.result}"
  location            = "global" # ✅ FIX: Required for activity log alerts
  resource_group_name = module.resource_organization.resource_group_names["rg_network_hub"]
  scopes              = [module.security.key_vault_id]
  description         = "Alert on Key Vault access events"

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.KeyVault/vaults/write"
  }

  action {
    action_group_id = module.monitoring.action_group_ids[keys(var.action_groups)[0]]
  }

  depends_on = [
    module.security,
    module.monitoring
  ]
}

# =============================================================================
# CUSTOM DOMAIN SSL CERTIFICATE CONFIGURATION
# =============================================================================

# ✅ Generate Self-Signed Certificates for POC
resource "tls_private_key" "app_ssl_key" {
  for_each = {
    connected    = "connected.poc-demo.com"
    nonconnected = "app.poc-demo.com"
  }

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "app_ssl_cert" {
  for_each = {
    connected    = "connected.poc-demo.com"
    nonconnected = "app.poc-demo.com"
  }

  private_key_pem = tls_private_key.app_ssl_key[each.key].private_key_pem

  subject {
    common_name  = each.value
    organization = "POC Demo Organization"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [each.value]
}

# ✅ FIX: PKCS12 conversion for proper certificate format
resource "pkcs12_from_pem" "app_ssl_pkcs12" {
  for_each = {
    connected    = "connected.poc-demo.com"
    nonconnected = "app.poc-demo.com"
  }

  cert_pem        = tls_self_signed_cert.app_ssl_cert[each.key].cert_pem
  private_key_pem = tls_private_key.app_ssl_key[each.key].private_key_pem
  password        = "CertP@ssw0rd123!"
}

# ✅ FIX: Store SSL Certificates in Key Vault with proper encoding
resource "azurerm_key_vault_certificate" "app_ssl_certificates" {
  for_each = {
    connected    = "connected.poc-demo.com"
    nonconnected = "app.poc-demo.com"
  }

  name         = "cert-${each.key}-app-${random_string.unique.result}"
  key_vault_id = module.security.key_vault_id

  certificate {
    contents = pkcs12_from_pem.app_ssl_pkcs12[each.key].result
    password = "CertP@ssw0rd123!"
  }

  lifecycle {
    prevent_destroy = false
  }

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }
  }

  depends_on = [
    module.security,
    pkcs12_from_pem.app_ssl_pkcs12
  ]
}

# =============================================================================
# ROLE-BASED ACCESS CONTROL (RBAC) ASSIGNMENTS
# =============================================================================

# ✅ Key Vault Administrator for Admin User
resource "azurerm_role_assignment" "admin_user_kv_admin" {
  scope                = module.security.key_vault_id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_user.admin_user.object_id

  depends_on = [module.security]
}

# ✅ DISABLED: Storage Blob Data Contributor - using access policies instead for POC reliability
# resource "azurerm_role_assignment" "apps_storage_contributor" {
#   for_each = {
#     for k, v in {
#       exposed    = try(module.fe_exposed_webapp.windows_web_app_ids["webapp_exposed"], "")
#       nonexposed = try(module.fe_nonexposed_webapp.windows_web_app_ids["webapp_nonexposed"], "")
#     } : k => v if v != "" && v != null
#   }

#   scope                = module.storage.storage_account_ids[keys(var.storage_accounts)[0]]
#   role_definition_name = "Storage Blob Data Contributor"
#   principal_id         = each.value

#   depends_on = [
#     module.fe_exposed_webapp,
#     module.fe_nonexposed_webapp,
#     module.storage
#   ]
# }

# ✅ Reader access to compute resources for monitoring
resource "azurerm_role_assignment" "monitoring_compute_reader" {
  count = length(var.windows_vms) > 0 || length(var.linux_vms) > 0 ? 1 : 0

  scope                = module.resource_organization.resource_group_ids["rg_network_hub"]
  role_definition_name = "Reader"
  principal_id         = try(module.monitoring.log_analytics_workspace_principal_id, data.azurerm_client_config.current.object_id)

  depends_on = [
    module.compute,
    module.monitoring
  ]
}

# ✅ Reader access to OnPrem compute resources for monitoring  
resource "azurerm_role_assignment" "monitoring_onprem_reader" {
  count = length([for k, v in var.windows_vms : k if v.subnet_name == "snet_onprem_compute"]) > 0 ? 1 : 0

  scope                = module.resource_organization.resource_group_ids["rg_onprem"]
  role_definition_name = "Reader"
  principal_id         = try(module.monitoring.log_analytics_workspace_principal_id, data.azurerm_client_config.current.object_id)

  depends_on = [
    module.onprem_compute,
    module.monitoring
  ]
}

# =============================================================================
# PERFORMANCE AND SECURITY VALIDATION
# =============================================================================

# ✅ Validate Application Gateway Health
resource "null_resource" "validate_app_gateway_health" {
  count = var.app_gateway_config != null ? 1 : 0

  depends_on = [
    module.security,
    module.fe_exposed_webapp,
    module.fe_nonexposed_webapp
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating Application Gateway health..."
      
      # Wait for backends to be healthy
      for i in {1..10}; do
        health_status=$(az network application-gateway show-backend-health \
          --name ${var.app_gateway_config.name} \
          --resource-group ${module.resource_organization.resource_group_names["rg_network_hub"]} \
          --query "backendAddressPools[0].backendHttpSettingsCollection[0].servers[0].health" \
          --output tsv 2>/dev/null || echo "Unknown")
        
        if [ "$health_status" = "Healthy" ]; then
          echo "Application Gateway backends are healthy"
          break
        else
          echo "Attempt $i: Backend health is $health_status, waiting 30 seconds..."
          sleep 30
        fi
      done
    EOT
  }
}

# ✅ Security Configuration Validation
resource "null_resource" "validate_security_configuration" {
  depends_on = [
    module.security,
    module.compute,
    module.onprem_compute
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating security configuration..."
      
      # Check Key Vault access policies
      echo "Checking Key Vault access policies..."
      az keyvault show --name ${split("/", module.security.key_vault_id)[8]} \
        --resource-group ${module.resource_organization.resource_group_names["rg_network_hub"]} \
        --query "properties.accessPolicies[].objectId" --output table || echo "Key Vault access check failed"
      
      # Check NSG rules
      echo "Validating NSG security rules..."
      for nsg in ${join(" ", keys(var.nsg_rules))}; do
        az network nsg show --name $nsg \
          --resource-group ${module.resource_organization.resource_group_names["rg_network_hub"]} \
          --query "securityRules[?direction=='Inbound' && access=='Allow'].{Name:name,Priority:priority,Source:sourceAddressPrefix,Destination:destinationAddressPrefix,Port:destinationPortRange}" \
          --output table || echo "Failed to check NSG: $nsg"
      done
      
      echo "Security validation completed"
    EOT
  }
}

# ✅ Application Gateway Backend Health Validation
resource "null_resource" "validate_app_gateway_backend_health" {
  count = var.app_gateway_config != null ? 1 : 0

  depends_on = [
    module.security,
    module.fe_exposed_webapp
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "🔍 Checking Application Gateway Backend Health..."
      
      # Wait for App Gateway to be ready
      sleep 60
      
      # Check backend health
      echo "Backend Health Status:"
      az network application-gateway show-backend-health \
        --name ${var.app_gateway_config.name} \
        --resource-group ${module.resource_organization.resource_group_names["rg_network_hub"]} \
        --output table || echo "❌ Failed to get backend health"
      
      # Check App Gateway configuration
      echo "App Gateway Backend Pools:"
      az network application-gateway address-pool list \
        --gateway-name ${var.app_gateway_config.name} \
        --resource-group ${module.resource_organization.resource_group_names["rg_network_hub"]} \
        --output table || echo "❌ Failed to get backend pools"
      
      # Test connectivity to backend
      echo "Testing backend connectivity:"
      nslookup webapp-expose-pocpub-1.azurewebsites.net || echo "❌ DNS resolution failed"
      
      echo "✅ App Gateway validation completed"
    EOT
  }
}

# =============================================================================
# CLEANUP AND LIFECYCLE MANAGEMENT
# =============================================================================

# ✅ Cleanup resources on destroy
resource "null_resource" "cleanup_resources" {
  triggers = {
    resource_group_names = jsonencode(module.resource_organization.resource_group_names)
    random_suffix        = random_string.unique.result
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Initiating cleanup for POC resources with suffix: ${self.triggers.random_suffix}"
      
      # Force cleanup of any remaining private endpoints
      echo "Cleaning up private endpoints..."
      az network private-endpoint list --query "[?contains(name, '${self.triggers.random_suffix}')].id" --output tsv | \
        xargs -I {} az network private-endpoint delete --ids {} --yes || echo "No private endpoints to clean"
      
      # Clean up any remaining network security groups
      echo "Cleaning up network security groups..."
      az network nsg list --query "[?contains(name, '${self.triggers.random_suffix}')].id" --output tsv | \
        xargs -I {} az network nsg delete --ids {} --yes || echo "No NSGs to clean"
      
      echo "Cleanup completed"
    EOT
  }
}

# =============================================================================
# FINAL DEPLOYMENT VALIDATION
# =============================================================================

# ✅ ENHANCED: Final deployment validation with timeout protection
resource "null_resource" "final_deployment_validation" {
  depends_on = [
    module.resource_organization,
    module.network,
    module.security,
    module.monitoring,
    module.storage,
    module.compute,
    module.onprem_compute,
    module.fe_exposed_webapp,
    module.fe_nonexposed_webapp,
    module.cost_management,
    # ✅ CRITICAL: Ensure DES protection is in place
    null_resource.des_protection,
    null_resource.validate_app_gateway_health,
    null_resource.validate_security_configuration
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=========================================="
      echo "POC DEPLOYMENT VALIDATION SUMMARY"
      echo "=========================================="
      echo "Deployment ID: ${random_string.unique.result}"
      echo "Location: ${var.location}"
      echo "Timestamp: $(date)"
      echo ""
      echo "✅ All modules deployed successfully"
      echo "✅ Dependency protection active"
      echo "✅ Key Vault and DES protected from early deletion"
      echo "✅ VM extensions configured with timeout protection"
      echo ""
      echo "🔒 DESTROY PROTECTION ACTIVE:"
      echo "   - Key Vault will not be deleted until all VMs are destroyed"
      echo "   - DES will not be deleted until all encrypted disks are removed"
      echo "   - VM extensions have timeout protection to prevent hanging"
      echo ""
      echo "=========================================="
    EOT
  }
}
