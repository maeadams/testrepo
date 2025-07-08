# =============================================================================
# TERRAFORM VARIABLES - SIMPLIFIED HUB-SPOKE ARCHITECTURE
# =============================================================================

# -----------------------------------------------------------------------------
# General Variables
# -----------------------------------------------------------------------------
variable "location" {
  description = "The Azure region for all resources."
  type        = string
}

variable "subscription_id" {
  description = "The Azure subscription ID."
  type        = string
}

# -----------------------------------------------------------------------------
# Resource Organization Module Variables
# -----------------------------------------------------------------------------
variable "management_group_config" {
  description = "Configuration for Management Groups."
  type = map(object({
    name         = string
    display_name = string
    parent_id    = optional(string)
  }))
  default = {}
}

variable "policy_definitions" {
  description = "Custom Azure Policy definitions"
  type = map(object({
    policy_type  = string
    mode         = string
    display_name = string
    description  = string
    policy_rule  = any # ✅ Changed from string to any
    metadata     = optional(string)
  }))
  default = {}
}

variable "policy_assignments" {
  description = "Configuration for Policy Assignments."
  type = map(object({
    scope                  = string
    policy_definition_name = string
    description            = string
    location               = string
    parameters             = optional(any)
  }))
  default = {}
}

variable "resource_groups" {
  description = "Configuration for Resource Groups."
  type = map(object({
    name     = string
    location = string
    tags     = optional(map(string))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Network Module Variables
# -----------------------------------------------------------------------------
variable "hub_vnet_config" {
  description = "Configuration for the Hub Virtual Network."
  type = object({
    name          = string
    address_space = list(string)
    tags          = optional(map(string))
  })
  default = null
}

variable "spoke_vnet_configs" {
  description = "Configuration for Spoke Virtual Networks."
  type = map(object({
    name          = string
    address_space = list(string)
    tags          = optional(map(string))
  }))
  default = {}
}

variable "subnet_configs" {
  description = "Configuration for Subnets."
  type = map(object({
    name                   = string
    address_prefixes       = list(string)
    virtual_network_name   = string
    network_security_group = optional(string)
    route_table            = optional(string)
    service_endpoints      = optional(list(string))
    delegation = optional(object({
      name               = string
      service_delegation = string
    }))
    private_endpoint_network_policies_enabled     = optional(bool)
    private_link_service_network_policies_enabled = optional(bool)
  }))
  default = {}
}

variable "nsg_rules" {
  description = "Configuration for Network Security Group rules."
  type = map(list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = optional(string)
  })))
  default = {}
}

variable "route_tables" {
  description = "Configuration for Route Tables."
  type = map(object({
    routes = list(object({
      name                   = string
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    }))
    tags                          = optional(map(string))
    disable_bgp_route_propagation = optional(bool, false)
  }))
  default = {}
}

variable "expressroute_gateway_config" {
  description = "Configuration for ExpressRoute Gateway."
  type = object({
    name       = string
    sku        = string
    subnet_key = string
    tags       = optional(map(string))
  })
  default = null
}

variable "vpn_gateway_config" {
  description = "Configuration for VPN Gateway."
  type = object({
    name          = string
    type          = string
    vpn_type      = string
    active_active = bool
    enable_bgp    = bool
    sku           = string
    generation    = optional(string)
    tags          = optional(map(string))
    connections = optional(map(object({
      name               = string
      type               = string
      shared_key         = string
      local_gateway_name = string
      local_gateway_ip   = string
      local_networks     = list(string)
    })))
  })
  default = null
}

variable "bastion_host_config" {
  description = "Configuration for Azure Bastion Host."
  type = object({
    name          = string
    subnet_key    = string
    public_ip_sku = optional(string, "Standard")
    tags          = optional(map(string))
  })
  default = null
}

variable "private_endpoint_configs" {
  description = "Configuration for Private Endpoints (generic for network module)."
  type = map(object({
    name      = string
    subnet_id = string
    private_service_connection = object({
      name                           = string
      is_manual_connection           = bool
      private_connection_resource_id = string
      subresource_names              = list(string)
    })
    private_dns_zone_group_name = optional(string, "default")
    private_dns_zone_ids        = list(string)
    tags                        = optional(map(string))
  }))
  default = {}
}

variable "eventgrid_source_arm_resource_id" {
  description = "ARM ID of the resource that is the source for Event Grid (e.g., storage account for flow logs)."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Security Module Variables
# -----------------------------------------------------------------------------
variable "firewall_config" {
  description = "Configuration for Azure Firewall."
  type = object({
    name                    = string
    sku_name                = string
    sku_tier                = string
    threat_intel_mode       = string
    public_ip_count         = number
    firewall_subnet_key_ref = string
    dns_servers             = optional(list(string))
    tags                    = optional(map(string))
  })
  default = null
}

variable "firewall_policy_rules" {
  description = "Configuration for Firewall Policy Rules."
  type = list(object({
    name     = string
    priority = number
    action   = string
    rules = list(object({
      name                  = string
      source_addresses      = list(string)
      destination_fqdns     = optional(list(string), [])
      destination_addresses = optional(list(string), [])
      protocols = list(object({
        type = string
        port = number
      }))
    }))
  }))
  default = []
}

variable "firewall_network_policy_rules" {
  description = "Firewall network policy rules configuration for TCP/UDP traffic"
  type = list(object({
    name     = string
    priority = number
    action   = string
    rules = list(object({
      name                  = string
      source_addresses      = list(string)
      destination_addresses = list(string)
      destination_ports     = list(string)
      protocols             = list(string)
    }))
  }))
  default = []
}

variable "app_gateway_config" {
  description = "Configuration for Application Gateway."
  type = object({
    name = string
    sku = object({
      name     = string
      tier     = string
      capacity = number
    })
    gateway_ip_configuration = list(object({
      name      = string
      subnet_id = string
    }))
    frontend_ip_configuration = list(object({
      name = string
    }))
    frontend_port = list(object({
      name = string
      port = number
    }))
    backend_address_pool = list(object({
      name  = string
      fqdns = optional(list(string))
    }))
    backend_http_settings = list(object({
      name                                = string
      cookie_based_affinity               = string
      port                                = number
      protocol                            = string
      request_timeout                     = number
      host_name                           = string
      pick_host_name_from_backend_address = optional(bool)
      probe_name                          = optional(string)
    }))
    http_listener = list(object({
      name                           = string
      frontend_ip_configuration_name = string
      frontend_port_name             = string
      protocol                       = string
    }))
    request_routing_rule = list(object({
      name                       = string
      rule_type                  = string
      http_listener_name         = string
      backend_address_pool_name  = string
      backend_http_settings_name = string
      priority                   = number
    }))
    probe = optional(list(object({
      name                                      = string
      protocol                                  = string
      path                                      = string
      interval                                  = number
      timeout                                   = number
      unhealthy_threshold                       = number
      host                                      = optional(string)
      pick_host_name_from_backend_http_settings = optional(bool)
      match = optional(object({
        status_code = list(string)
        body        = string
      }))
    })))
    waf_configuration = optional(object({
      enabled          = bool
      firewall_mode    = string
      rule_set_type    = string
      rule_set_version = string
    }))
    tags = optional(map(string))
  })
  default = null
}

variable "waf_policy_config" {
  description = "Configuration for WAF Policy."
  type = object({
    name = string
    tags = optional(map(string))
  })
  default = null
}

variable "key_vault_config" {
  description = "Configuration for Key Vault."
  type = object({
    name                            = string
    sku_name                        = string
    enabled_for_disk_encryption     = bool
    enabled_for_template_deployment = bool
    enable_rbac_authorization       = bool
    soft_delete_retention_days      = number
    purge_protection_enabled        = bool
    access_policies = list(object({
      tenant_id               = string
      object_id               = string
      key_permissions         = list(string)
      secret_permissions      = list(string)
      certificate_permissions = list(string)
    }))
    tags = optional(map(string))
  })
  default = null
}

variable "encryption_keys" {
  description = "Configuration for Key Vault Encryption Keys."
  type = map(object({
    name     = string
    key_type = string
    key_size = number
    key_opts = list(string)
    tags     = optional(map(string))
  }))
  default = {}
}

variable "key_vault_secrets" {
  description = "Configuration for Key Vault Secrets."
  type = map(object({
    name  = string
    value = string
    tags  = optional(map(string))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Identity Module Variables
# -----------------------------------------------------------------------------
variable "custom_roles" {
  description = "Configuration for Custom RBAC Roles."
  type = map(object({
    name        = string
    description = string
    permissions = list(object({
      actions          = list(string)
      not_actions      = list(string)
      data_actions     = list(string)
      not_data_actions = list(string)
    }))
    assignable_scopes = list(string)
  }))
  default = {}
}

variable "role_assignments" {
  description = "Configuration for Role Assignments."
  type = map(object({
    name                 = optional(string)
    scope                = string
    role_definition_id   = optional(string)
    role_definition_name = optional(string)
    principal_id         = string
  }))
  default = {}
}

variable "managed_identities" {
  description = "Configuration for Managed Identities."
  type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    tags                = optional(map(string))
  }))
  default = {}
}

variable "identity_providers" {
  description = "Configuration for Identity Providers (OIDC/SAML)."
  type = map(object({
    name          = string
    redirect_uris = list(string)
    required_resource_access = object({
      resource_app_id = string
      resource_access = object({
        id   = string
        type = string
      })
    })
    issuer            = optional(string)
    allowed_audiences = optional(list(string))
    type              = optional(string)
  }))
  default = {}
}

variable "application_owner_object_id" {
  description = "The Object ID of the user or service principal to be assigned as the owner of the created App Registrations."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Monitoring Module Variables
# -----------------------------------------------------------------------------
variable "workspace_config" {
  description = "Configuration for Log Analytics Workspace."
  type = object({
    name              = string
    sku               = string
    retention_in_days = optional(number)
    tags              = optional(map(string))
  })
  default = null
}

variable "action_groups" {
  description = "Configuration for Action Groups."
  type = map(object({
    name       = string
    short_name = string
    email_receivers = optional(list(object({
      name                    = string
      email_address           = string
      use_common_alert_schema = optional(bool, true)
    })), [])
    sms_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })), [])
    webhook_receivers = optional(list(object({
      name        = string
      service_uri = string
    })), [])
    tags = optional(map(string))
  }))
  default = {}
}


variable "metric_alerts" {
  description = "Configuration for metric alerts"
  type = map(object({
    name                = string
    resource_group_name = string
    scopes              = list(string)
    description         = string
    criteria = object({
      metric_namespace = string
      metric_name      = string
      aggregation      = string
      operator         = string
      threshold        = number
    })
    frequency        = string
    window_size      = string
    severity         = number
    action_group_ids = list(string)
  }))
  default = {}
}

variable "query_alerts" {
  description = "Configuration for log query alerts"
  type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    description         = string
    query               = string
    frequency           = string
    time_window         = string
    severity            = number
    threshold           = number
    action_group_ids    = list(string)
  }))
  default = {}
}

variable "service_health_alerts" {
  description = "Configuration for Service Health alerts"
  type = map(object({
    name    = string
    enabled = bool
    scopes  = list(string)
    criteria = object({
      service_health = list(object({
        locations = list(string)
        events    = list(string)
      }))
    })
    action_group_ids = list(string)
    tags             = optional(map(string))
  }))
  default = {}
}

variable "diagnostic_settings" {
  description = "Configuration for Diagnostic Settings"
  type = map(object({
    name                       = string
    target_resource_id         = string
    log_analytics_workspace_id = string
    logs = list(object({
      category = string
      enabled  = bool
      retention_policy = object({
        enabled = bool
        days    = number
      })
    }))
    metrics = list(object({
      category = string
      enabled  = bool
      retention_policy = object({
        enabled = bool
        days    = number
      })
    }))
  }))
  default = {}
}

variable "data_collection_rules" {
  description = "Configuration for Data Collection Rules"
  type = map(object({
    name = string
    destinations = list(object({
      name                  = string
      workspace_resource_id = string
    }))
    data_sources = optional(object({
      windows_event_log = optional(list(object({
        name           = string
        streams        = list(string)
        x_path_queries = list(string)
      })), [])
    }))
    tags = optional(map(string))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Storage Module Variables
# -----------------------------------------------------------------------------
variable "storage_accounts" {
  description = "Configuration for Storage Accounts."
  type = map(object({
    name                              = string
    account_tier                      = string
    account_replication_type          = string
    account_kind                      = string
    access_tier                       = optional(string)
    versioning_enabled                = optional(bool, false)
    blob_soft_delete_retention_days   = optional(number, 7)
    min_tls_version                   = optional(string, "TLS1_2")
    https_traffic_only_enabled        = optional(bool, true)
    infrastructure_encryption_enabled = optional(bool, false)
    tags                              = optional(map(string), {})
  }))
  default = {}
}

variable "storage_containers" {
  description = "Configuration for Storage Containers."
  type = map(object({
    name                    = string
    storage_account_key_ref = string
    container_access_type   = string
  }))
  default = {}
}

variable "managed_disks" {
  description = "Configuration for Managed Disks."
  type = map(object({
    name                 = string
    storage_account_type = string
    create_option        = string
    disk_size_gb         = number
    tags                 = optional(map(string), {})
  }))
  default = {}
}

variable "recovery_services_vault_config" {
  description = "Configuration for Recovery Services Vault."
  type = object({
    name                = string
    sku                 = string
    soft_delete_enabled = bool
    tags                = optional(map(string), {})
  })
  default = null
}

variable "backup_policies_vm" {
  description = "Configuration for VM backup policies"
  type = map(object({
    name = string
    backup = object({
      frequency = string
      time      = string
    })
    retention_daily = object({
      count = number
    })
    retention_weekly = optional(object({
      count    = number
      weekdays = list(string)
    }))
    retention_monthly = optional(object({
      count    = number
      weekdays = list(string)
      weeks    = list(string)
    }))
    retention_yearly = optional(object({
      count    = number
      weekdays = list(string)
      weeks    = list(string)
      months   = list(string)
    }))
    recovery_vault_name = optional(string)
  }))
  default = {}
}

variable "vms_to_backup" {
  description = "Configuration for VMs to Backup."
  type = map(object({
    vm_name             = string
    backup_policy_name  = string
    resource_group_name = string
  }))
  default = {}
}

variable "site_recovery_config" {
  description = "Configuration for Site Recovery."
  type = object({
    fabric_name = string
  })
  default = null
}

# -----------------------------------------------------------------------------
# Compute Module Variables
# -----------------------------------------------------------------------------
variable "disk_encryption_set_config" {
  description = "Configuration for Disk Encryption Set."
  type = object({
    name_prefix = string
    tags        = optional(map(string))
  })
  default = null
}

variable "windows_vms" {
  description = "Configuration for Windows VMs."
  type = map(object({
    name_prefix    = string
    computer_name  = optional(string)
    size           = string
    admin_username = string
    admin_password = string
    subnet_name    = string
    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    os_disk = object({
      caching              = string
      storage_account_type = string
    })
    data_disks = optional(list(object({
      name                 = string
      lun                  = number
      caching              = string
      storage_account_type = string
      disk_size_gb         = number
      create_option        = string
    })), [])
    enable_azure_monitor_agent = optional(bool, true)
    tags                       = optional(map(string))
  }))
  default = {}
}

variable "linux_vms" {
  description = "Configuration for Linux VMs."
  type = map(object({
    name_prefix    = string
    size           = string
    admin_username = string
    admin_ssh_key = object({
      username   = string
      public_key = string
    })
    subnet_name = string
    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    os_disk = object({
      caching              = string
      storage_account_type = string
    })
    data_disks = optional(list(object({
      name                 = string
      lun                  = number
      caching              = string
      storage_account_type = string
      disk_size_gb         = number
      create_option        = string
    })), [])
    enable_azure_monitor_agent = optional(bool, true)
    tags                       = optional(map(string))
  }))
  default = {}
}

variable "vm_extensions_raw" {
  description = "VM extensions with object settings (will be JSON-encoded)"
  type = map(object({
    name                      = string
    virtual_machine_name      = string
    publisher                 = string
    type                      = string
    type_handler_version      = string
    settings_object           = optional(any)
    protected_settings_object = optional(any)
    tags                      = optional(map(string))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Web Applications Module Variables
# -----------------------------------------------------------------------------


variable "web_apps" {
  description = "Map of Windows / Linux Azure Web-Apps to deploy"
  type = map(object({
    # ---------- mandatory ----------
    name                = string
    resource_group_name = string
    location            = string
    service_plan_key    = string

    # ---------- optional ----------
    os_type                       = optional(string, "Windows") # "Windows" | "Linux"
    https_only                    = optional(bool, true)
    public_network_access_enabled = optional(bool, true)

    # VNet integration
    vnet_integration_enabled = optional(bool, false)
    vnet_integration_subnet  = optional(string)

    # Private-endpoint
    private_endpoint_enabled = optional(bool, false)
    private_endpoint_subnet  = optional(string)

    # IP restrictions
    ip_restrictions = optional(list(object({
      name       = string
      ip_address = string
      priority   = optional(number)
      action     = optional(string, "Allow")
    })), [])

    # Application-specific settings
    app_settings = optional(map(string), {})

    # Site-config block
    site_config = optional(object({
      always_on                = optional(bool, false)
      http2_enabled            = optional(bool, false)
      dotnet_framework_version = optional(string)
      linux_fx_version         = optional(string)
      default_documents        = optional(list(string), [])
    }))

    # Tags
    tags = optional(map(string), {})
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Database Module Variables
# -----------------------------------------------------------------------------
variable "mi_subnet_key" {
  description = "The key for the SQL MI subnet in the subnet_ids map"
  type        = string
  default     = "snet_connected_database"
}

# ✅ CRITICAL: SQL MI enable flag for cost and time control
variable "enable_sql_mi" {
  description = "Enable or disable SQL Managed Instance deployment. Set to false to skip SQL MI for faster/cheaper deployments."
  type        = bool
  default     = true
}

variable "mi_settings" {
  description = "Configuration for SQL Managed Instance."
  type = object({
    name_prefix                                  = string
    sku_name                                     = string
    vcores                                       = number
    storage_size_in_gb                           = number
    administrator_login                          = string
    administrator_login_password                 = string
    public_data_endpoint_enabled                 = bool
    collation                                    = string
    license_type                                 = string
    proxy_override                               = string
    timezone_id                                  = string
    minimal_tls_version                          = optional(string)
    transparent_data_encryption_key_vault_key_id = optional(string)
    tags                                         = map(string)
  })
  default = null
}

variable "private_endpoint_config" {
  description = "Configuration for SQL Private Endpoint."
  type = map(object({
    name      = string
    subnet_id = string
    private_service_connection = object({
      name                 = string
      is_manual_connection = bool
      subresource_names    = list(string)
    })
    private_dns_zone_name = string
  }))
  default = {}
}

variable "private_endpoint_config_sql" {
  description = "Configuration for SQL Managed Instance Private Endpoint."
  type = map(object({
    name      = string
    subnet_id = string
    private_service_connection = object({
      name                 = string
      is_manual_connection = bool
      subresource_names    = list(string)
    })
    private_dns_zone_name = string
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Application Module Variables
# -----------------------------------------------------------------------------
variable "app_service_plans" {
  description = "Configuration for App Service Plans."
  type = map(object({
    name                     = string
    sku_name                 = string
    os_type                  = string
    per_site_scaling_enabled = optional(bool, false)
    tags                     = optional(map(string))
  }))
  default = {}
}

variable "app_services" {
  description = "Configuration for App Services."
  type = map(object({
    name                            = string
    app_service_plan_key            = string
    os_type                         = optional(string, "linux")
    enable_vnet_integration         = optional(bool, false)
    vnet_integration_subnet_key_ref = optional(string)
    https_only                      = optional(bool, true)
    site_config = optional(object({
      always_on                 = optional(bool)
      dotnet_framework_version  = optional(string)
      linux_fx_version          = optional(string)
      windows_fx_version        = optional(string)
      php_version               = optional(string)
      python_version            = optional(string)
      java_version              = optional(string)
      java_container            = optional(string)
      java_container_version    = optional(string)
      min_tls_version           = optional(string, "1.2")
      ftps_state                = optional(string, "FtpsOnly")
      http2_enabled             = optional(bool, true)
      use_32_bit_worker_process = optional(bool)
    }))
    app_settings = optional(map(string))
    connection_string = optional(list(object({
      name  = string
      type  = string
      value = string
    })), [])
    tags = optional(map(string))
  }))
  default = {}
}

variable "function_apps" {
  description = "Configuration for Function Apps."
  type = map(object({
    name                       = string
    app_service_plan_id        = string
    storage_account_name       = string
    storage_account_access_key = string
    https_only                 = optional(bool, true)
    version                    = optional(string, "~4")
    site_config = optional(object({
      always_on        = optional(bool)
      linux_fx_version = optional(string)
      dotnet_version   = optional(string)
    }))
    app_settings               = optional(map(string))
    vnet_integration_subnet_id = optional(string)
    tags                       = optional(map(string))
  }))
  default = {}
}

variable "app_service_custom_hostnames" {
  description = "Configuration for App Service Custom Hostnames."
  type = map(object({
    app_service_name = string
    hostname         = string
    ssl_state        = optional(string)
    thumbprint       = optional(string)
  }))
  default = {}
}

variable "app_service_certificates" {
  description = "Configuration for App Service Certificates."
  type = map(object({
    name                = string
    app_service_name    = string
    pfx_blob            = optional(string)
    password            = optional(string)
    key_vault_secret_id = optional(string)
    tags                = optional(map(string))
  }))
  default = {}
}

variable "app_authentication_settings" {
  description = "App Service authentication settings"
  type = map(object({
    app_service_key               = string
    enabled                       = bool
    unauthenticated_client_action = string
    default_provider              = string
    active_directory_settings = object({
      client_id                  = string
      allowed_audiences          = list(string)
      client_secret_setting_name = string
    })
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Cost Management Module Variables
# -----------------------------------------------------------------------------
variable "subscription_budget" {
  description = "Configuration for Subscription Budget."
  type = object({
    name        = string
    amount      = number
    time_period = string
    start_date  = string
    end_date    = string
    notifications = list(object({
      enabled        = bool
      operator       = string
      threshold      = number
      contact_emails = list(string)
      contact_groups = optional(list(string))
      contact_roles  = optional(list(string))
      threshold_type = optional(string, "Actual")
    }))
    filter = optional(object({
      dimensions = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })))
      tags = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })))
    }))
  })
  default = null
}

variable "resource_group_budgets" {
  description = "Configuration for Resource Group Budgets."
  type = map(object({
    name                = string
    resource_group_name = string
    amount              = number
    time_period         = string
    start_date          = string
    end_date            = string
    notifications = list(object({
      enabled        = bool
      operator       = string
      threshold      = number
      contact_emails = list(string)
      contact_groups = optional(list(string))
      contact_roles  = optional(list(string))
      threshold_type = optional(string, "Actual")
    }))

    filter = optional(object({
      dimensions = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })))
      tags = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })))
    }))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# CDN & Caching Module Variables
# -----------------------------------------------------------------------------
variable "frontdoor_config" {
  description = "Configuration for Front Door."
  type = object({
    name = string
    routing_rules = list(object({
      name               = string
      accepted_protocols = list(string)
      patterns_to_match  = list(string)
      enabled            = bool
      forwarding_configuration = object({
        backend_pool_name   = string
        forwarding_protocol = string
      })
    }))
    backend_pools = list(object({
      name = string
      backends = list(object({
        host_header = string
        address     = string
        http_port   = number
        https_port  = number
        weight      = number
        priority    = number
      }))
      load_balancing_name = string
      health_probe_name   = string
    }))
    tags = optional(map(string))
  })
  default = null
}

variable "frontdoor_waf_policy_config" {
  description = "Configuration for Front Door WAF Policy."
  type = object({
    name    = string
    enabled = bool
    mode    = string
    managed_rules = optional(list(object({
      type    = string
      version = string
    })))
    tags = optional(map(string))
  })
  default = null
}

variable "frontdoor_custom_https_config" {
  description = "Configuration for Front Door Custom HTTPS."
  type        = map(any)
  default     = {}
}

variable "redis_cache_config" {
  description = "Configuration for Redis Cache."
  type = map(object({
    name                = string
    capacity            = number
    family              = string
    sku_name            = string
    enable_non_ssl_port = optional(bool, false)
    minimum_tls_version = optional(string, "1.2")
    subnet_id           = optional(string)
    static_ip_address   = optional(string)
    redis_configuration = optional(object({
      maxmemory_reserved              = optional(string)
      maxmemory_delta                 = optional(string)
      maxfragmentationmemory_reserved = optional(string)
      rdb_backup_enabled              = optional(bool)
      rdb_backup_frequency            = optional(string)
      rdb_backup_max_snapshot_count   = optional(number)
      rdb_storage_connection_string   = optional(string)
    }))
    patch_schedule = optional(list(object({
      day_of_week        = string
      start_hour_utc     = number
      maintenance_window = optional(string)
    })), [])
    tags = optional(map(string))
  }))
  default = {}
}

variable "redis_firewall_rules" {
  description = "Configuration for Redis Firewall Rules."
  type = map(object({
    redis_cache_name = string
    name             = string
    start_ip         = string
    end_ip           = string
  }))
  default = {}
}

variable "redis_private_endpoint_config" {
  description = "Configuration for Redis Private Endpoint."
  type = map(object({
    redis_cache_name      = string
    name                  = string
    subnet_id             = string
    private_dns_zone_name = string
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Flow Log Configuration Variables
# -----------------------------------------------------------------------------
variable "flow_log_config" {
  description = "Configuration for VNet Flow Logs."
  type = object({
    name     = string
    nsg_name = string
    enabled  = bool
    retention_policy = object({
      days    = number
      enabled = bool
    })
    traffic_analytics = optional(object({
      enabled             = bool
      interval_in_minutes = optional(number)
    }))
  })
  default = null
}

variable "root_flow_log_config" {
  description = "Configuration for the root-level network watcher flow log."
  type = object({
    name               = string
    nsg_name           = string
    storage_account_id = string
    enabled            = bool
    retention_policy = object({
      enabled = bool
      days    = number
    })
    traffic_analytics = optional(object({
      enabled               = bool
      workspace_id          = string
      workspace_resource_id = string
      interval_in_minutes   = optional(number)
    }))
  })
  default = null
}

variable "flow_log_config_storage_account_name_for_eventgrid" {
  description = "The name (key) of the storage account in var.storage_accounts to be used as the source for Event Grid for flow logs."
  type        = string
  default     = "default_storage_for_flow_logs"
}

# -----------------------------------------------------------------------------
# Admin User Configuration Variables
# -----------------------------------------------------------------------------
variable "admin_user_principal_name" {
  description = "Principal name of the admin user"
  type        = string
  default     = "admin@yourdomain.com" # Change this to your actual admin UPN
}

variable "linux_admin_ssh_public_key_path" {
  description = "Path to the SSH public key file for Linux VM admin user."
  type        = string
  default     = "./cmk_rsa/id_rsa_azure_vm.pub"
}

# -----------------------------------------------------------------------------
# Key Reference Variables (for cross-module dependencies)
# -----------------------------------------------------------------------------
variable "vm_encryption_key_name" {
  description = "Name of the VM encryption key in Key Vault"
  type        = string
  default     = "key_vm_disk_encryption"
}

variable "windows_events_dcr_name" {
  description = "Name of the Windows events Data Collection Rule"
  type        = string
  default     = "dcr_windows_security_events"
}

# -----------------------------------------------------------------------------
# Route Table Configuration Variables
# -----------------------------------------------------------------------------
variable "mi_subnet_config" {
  description = "Configuration for SQL MI Subnet."
  type        = any
  default     = {}
}

variable "mi_nsg_rules" {
  description = "Configuration for SQL MI NSG Rules."
  type        = any
  default     = []
}

variable "mi_route_table_name" {
  description = "Name for SQL MI Route Table."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Additional Runtime Variables (populated by modules)
# -----------------------------------------------------------------------------
variable "random_suffix" {
  description = "Random suffix for unique naming (generated at runtime)"
  type        = string
  default     = ""
}

variable "security_resource_group_name" {
  description = "Resource group name for security resources like DES"
  type        = string
  default     = ""
}

variable "network_resource_group_name" {
  description = "Network resource group name for firewall deployment"
  type        = string
  default     = ""
}

variable "key_vault_id" {
  description = "Key Vault ID for secrets (populated by security module)"
  type        = string
  default     = ""
}

variable "key_vault_key_ids" {
  description = "Map of Key Vault key IDs (populated by security module)"
  type        = map(string)
  default     = {}
}

variable "disk_encryption_key_url" {
  description = "The URL of the Key Vault Key for disk encryption (populated by security module)"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace (populated by monitoring module)"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_key" {
  description = "The primary shared key of the Log Analytics workspace (populated by monitoring module)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "windows_events_dcr_id" {
  description = "ID of the Data Collection Rule for Windows events (populated by monitoring module)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Map of subnet names to their IDs (populated by network module)"
  type        = map(string)
  default     = {}
}

variable "vnet_id" {
  description = "The ID of the VNet where resources are deployed (populated by network module)"
  type        = string
  default     = ""
}

variable "app_insights_key" {
  description = "Application Insights instrumentation key (populated by monitoring module)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "connected_webapp_fqdn" {
  description = "FQDN of the connected web app (populated by application module)"
  type        = string
  default     = ""
}

variable "nonconnected_webapp_fqdn" {
  description = "FQDN of the non-connected web app (populated by application module)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Deprecated/Legacy Variables (for backward compatibility)
# -----------------------------------------------------------------------------
variable "vm_backup_policies" {
  description = "VM backup policies (legacy - use backup_policies_vm instead)"
  type        = map(any)
  default     = {}
}


variable "nat_gateway_config" {
  description = "Configuration for NAT Gateway"
  type = object({
    name                = string
    location            = string
    subnet_associations = list(string)
    tags                = optional(map(string))
  })
  default = null
}

variable "dns_resolver_config" {
  description = "Configuration for DNS Resolver"
  type = object({
    name               = string
    virtual_network_id = string
    inbound_endpoint = object({
      name                         = string
      subnet_id                    = string
      private_ip_allocation_method = string
    })
    outbound_endpoint = object({
      name      = string
      subnet_id = string
    })
    forwarding_rulesets = list(object({
      name = string
      rules = list(object({
        name        = string
        domain_name = string
        target_dns_servers = list(object({
          ip_address = string
          port       = number
        }))
      }))
    }))
    tags = optional(map(string))
  })
  default = null
}

# =============================================================================
# END OF VARIABLES.TF - SIMPLIFIED HUB-SPOKE ARCHITECTURE
# =============================================================================
