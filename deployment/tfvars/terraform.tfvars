# =============================================================================
# TERRAFORM.TFVARS - AZURE COMMERCIAL LANDING ZONE POC
# =============================================================================

# -----------------------------------------------------------------------------
# Basic Configuration
# -----------------------------------------------------------------------------
location                  = "France Central"
subscription_id           = "7445ae6f-a879-4d74-9a49-eebda848dc6c"
admin_user_principal_name = "maeva@MngEnvMCAP334656.onmicrosoft.com"
# -----------------------------------------------------------------------------
# Resource Organization (EXACT STRUCTURE)
# -----------------------------------------------------------------------------
management_group_config = {
  "root" = {
    name         = "mg-cltroot-POCpub-1"
    display_name = "CLT Root POC France Central"
    parent_id    = null
  }
}


# Azure Firewall Configuration
firewall_config = {
  name                    = "afw-hub-POCpub-1"
  sku_name                = "AZFW_VNet"
  sku_tier                = "Standard"
  public_ip_count         = 1
  threat_intel_mode       = "Alert"
  firewall_subnet_key_ref = "snet_hub_firewall" # ✅ Must match subnet key
  tags = {
    Environment = "POC"
    Purpose     = "HubFirewall"
  }
}

# ✅ FIXED: Firewall Policy Rules
firewall_policy_rules = [
  {
    name     = "AllowNonExposeInternet"
    priority = 200
    action   = "Allow"
    rules = [
      {
        name                  = "Allow-NonExpose-Outbound"
        source_addresses      = ["10.1.0.0/24"]
        destination_fqdns     = ["*.microsoft.com", "*.azure.com", "*.windows.net", "*.ubuntu.com"]
        destination_addresses = []
        protocols = [
          {
            type = "Https"
            port = 443
          },
          {
            type = "Http"
            port = 80
          }
        ]
      }
    ]
  },
  {
    name     = "AllowOnPremCommunication"
    priority = 300
    action   = "Allow"
    rules = [
      {
        name                  = "Allow-OnPrem-to-Internet"
        source_addresses      = ["192.168.0.0/22"]
        destination_fqdns     = ["*.microsoft.com", "*.azure.com", "*.windows.net"] # ✅ FIXED: Use FQDNs instead of IPs
        destination_addresses = []                                                  # ✅ FIXED: Empty for application rules
        protocols = [
          {
            type = "Https"
            port = 443
          },
          {
            type = "Http"
            port = 80
          }
        ]
      }
    ]
  }
]

# ✅ ADD: Network rules for IP-based traffic
firewall_network_policy_rules = [
  {
    name     = "AllowOnPremToApps"
    priority = 400
    action   = "Allow"
    rules = [
      {
        name                  = "Allow-OnPrem-to-Apps-Network"
        source_addresses      = ["192.168.0.0/22"]
        destination_addresses = ["10.2.0.0/24", "10.1.0.0/24",]
        destination_ports     = ["80", "443", "3389", "22", "1433"]
        protocols             = ["TCP"]
      }
    ]
  }, {
    name     = "AllowOnPremToNonExpose"
    priority = 350  # New rule
    action   = "Allow"
    rules = [
      {
        name                  = "Allow-OnPrem-to-NonExpose-PE"
        source_addresses      = ["192.168.0.0/22"]
        destination_addresses = ["10.1.0.64/26"]  # Private endpoint subnet
        destination_ports     = ["80", "443"]
        protocols             = ["TCP"]
      }
    ]
  }
]

# Application Gateway Configuration
app_gateway_config = {
  name = "agw-hub-POCpub-1"
  sku = {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }
  gateway_ip_configuration = [
    {
      name      = "agw-ip-config"
      subnet_id = "snet_hub_agw"
    }
  ]
  frontend_ip_configuration = [
    {
      name = "agw-frontend-ip"
    }
  ]
  frontend_port = [
    {
      name = "port_80"
      port = 80
    },
    {
      name = "port_443"
      port = 443
    }
  ]
  backend_address_pool = [
    {
      name  = "pool-expose-app"
      fqdns = ["webapp-expose-pocpub-1.azurewebsites.net"]
    }
  ]

  http_listener = [
    {
      name                           = "listener-expose"
      frontend_ip_configuration_name = "agw-frontend-ip"
      frontend_port_name             = "port_80"
      protocol                       = "Http"
      host_name                      = ""
      host_names                     = []
      require_sni                    = false
      ssl_certificate_name           = ""
    }
  ]
  request_routing_rule = [
    {
      name                        = "rule-expose-app"
      rule_type                   = "Basic"
      http_listener_name          = "listener-expose"
      backend_address_pool_name   = "pool-expose-app"
      backend_http_settings_name  = "http-settings-expose"
      redirect_configuration_name = ""
      rewrite_rule_set_name       = ""
      url_path_map_name           = ""
      priority                    = 100
    }
  ]
  probe = [
    {
      name                = "probe-expose"
      protocol            = "Http"
      host                = "webapp-expose-pocpub-1.azurewebsites.net" # <-- PATCH
      path                = "/"
      interval            = 30
      timeout             = 30
      unhealthy_threshold = 3
      match = {
        status_code = ["200-399", "403", "404"]
        body        = ""
      }
    }
  ]

  backend_http_settings = [
    {
      name                                      = "http-settings-expose" # ✅ Matches routing rule
      cookie_based_affinity                     = "Disabled"
      port                                      = 80
      protocol                                  = "Http"
      request_timeout                           = 60
      pick_host_name_from_backend_http_settings = true
      probe_name                                = "probe-expose"
      host_name                                 = "webapp-expose-pocpub-1.azurewebsites.net" # ✅ From second config
      path                                      = "/"
    }
  ]
  waf_configuration = {
    enabled                  = true
    firewall_mode            = "Prevention"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    disabled_rule_group      = []
    file_upload_limit_mb     = 100
    request_body_check       = true
    max_request_body_size_kb = 128
  }
  ssl_certificate            = []
  trusted_root_certificate   = []
  ssl_profile                = []
  authentication_certificate = []
  redirect_configuration     = []
  rewrite_rule_set           = []
  url_path_map               = []
  custom_error_configuration = []

  tags = {
    Environment = "POC"
    Purpose     = "Internet-to-Expose-App"
  }
}

# ✅ WEB APPLICATIONS - WITH PROPER SECURITY
# ✅ WEBAPP EXPOSED - Public 403, AGW 200, Private Endpoint Access
web_apps = {
 webapp_exposed = {
    name                = "webapp-expose-pocpub-1"
    resource_group_name = "fe-exposed-connected-apps"
    location            = "France Central"
    service_plan_key    = "asp_fe_exposed"

    os_type                       = "Windows"
    https_only                    = false
    public_network_access_enabled = true  # ✅ REQUIRED for App Gateway

    vnet_integration_enabled = true
    vnet_integration_subnet  = "snet_integration_expose"

    private_endpoint_enabled = true
    private_endpoint_subnet  = "snet_pep_expose"

    # ✅ STRICT IP RESTRICTIONS: Only App Gateway allowed
    ip_restrictions = [
      {
        name       = "AllowAppGatewaySubnet"
        ip_address = "10.0.0.64/26"  # App Gateway subnet
        priority   = 100
        action     = "Allow"
      },
      {
        name       = "DenyAllOther"
        ip_address = "0.0.0.0/0"     # Deny everything else
        priority   = 300
        action     = "Deny"
      }
    ]

    # App settings
    app_settings = {
      WEBSITE_RUN_FROM_PACKAGE        = "0"
      APPINSIGHTS_INSTRUMENTATIONKEY  = "placeholder"
      WEBSITE_DISABLE_ARR_SSL         = "true"
      WEBSITE_LOAD_USER_PROFILE       = "1"
      WEBSITE_ENABLE_SYNC_UPDATE_SITE = "true"
    }

    # Site-config
    site_config = {
      always_on                = true
      http2_enabled            = true
      dotnet_framework_version = "v6.0"
      default_documents        = ["index.html", "default.aspx"]
    }

    tags = {
      Environment = "POC"
      Purpose     = "ExposedWebApplication"
      Access      = "AGW-Only-Public-Blocked"
    }
  }

  webapp_nonexposed = {
    name                = "webapp-nonexpose-pocpub-1"
    resource_group_name = "fe-non-exposed-connected-apps"
    location            = "France Central"
    service_plan_key    = "asp_fe_nonexposed"

    os_type                       = "Windows"
    https_only                    = true
    public_network_access_enabled = false

    vnet_integration_enabled = true
    vnet_integration_subnet  = "snet_integration_nonexpose"

    private_endpoint_enabled = true
    private_endpoint_subnet  = "snet_pep_nonexpose"

    ip_restrictions = [
      {
        name       = "AllowOnPremVMSubnet" # NEW
        ip_address = "192.168.1.0/24"      # on-prem compute subnet
        priority   = 100
        action     = "Allow"
      },
      {
        name       = "AllowAdminVMSubnet" # NEW
        ip_address = "10.0.0.160/27"
        priority   = 150 # lower than the final deny
        action     = "Allow"
      },
      {
        name       = "DenyPublicInternet"
        ip_address = "0.0.0.0/0"
        priority   = 200
        action     = "Deny"
    }]

    app_settings = {
      WEBSITE_RUN_FROM_PACKAGE       = "0"
      APPINSIGHTS_INSTRUMENTATIONKEY = "placeholder"
      WEBSITE_LOAD_USER_PROFILE      = "1"
    }

    site_config = {
      always_on                = true
      http2_enabled            = true
      dotnet_framework_version = "v6.0"
      default_documents        = ["index.html", "default.aspx"]
    }

    tags = {
      Environment = "POC"
      Purpose     = "NonExposedWebApplication"
      Access      = "Private-Endpoint-Only"
    }
  }
}



policy_definitions = {
  "DenyExpensiveVMs" = {
    policy_type  = "Custom"
    mode         = "All"
    display_name = "Deny Expensive VM SKUs"
    description  = "Prevents deployment of expensive VM SKUs in POC environment"
    policy_rule = {
      if = {
        allOf = [
          {
            field  = "type"
            equals = "Microsoft.Compute/virtualMachines"
          },
          {
            anyOf = [
              {
                field = "Microsoft.Compute/virtualMachines/sku.name"
                like  = "Standard_D*_v5"
              },
              {
                field = "Microsoft.Compute/virtualMachines/sku.name"
                like  = "Standard_E*"
              }
            ]
          }
        ]
      }
      then = {
        effect = "deny"
      }
    }
  }
}

policy_assignments = {
  "DenyExpensiveVMs" = {
    scope                  = "7445ae6f-a879-4d74-9a49-eebda848dc6c"
    policy_definition_name = "DenyExpensiveVMs"
    description            = "Prevent expensive VM deployments"
    location               = "France Central"
  }
}

# TARGET RESOURCE GROUP STRUCTURE (6 groups)
resource_groups = {
  # On-Premises Integration
  "rg_onprem" = {
    name     = "on-prem"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "OnPremiseSimulation"
    }
  }

  # Network Hub (Central Hub) - Consolidates network, security, admin, shared services
  "rg_network_hub" = {
    name     = "network-hub"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "CentralizedHubInfrastructure"
    }
  }

  # Frontend Exposed Connected Apps
  "rg_fe_exposed_apps" = {
    name     = "fe-exposed-connected-apps"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "FrontendExposedApplications"
    }
  }

  # Backend Exposed Connected Apps
  "rg_be_exposed_apps" = {
    name     = "be-exposed-connected-apps"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "BackendExposedDatabases"
    }
  }

  # Frontend Non-Exposed Connected Apps
  "rg_fe_nonexposed_apps" = {
    name     = "fe-non-exposed-connected-apps"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "FrontendNonExposedApplications"
    }
  }

  # Backend Non-Exposed Connected Apps
  "rg_be_nonexposed_apps" = {
    name     = "be-non-exposed-connected-apps"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "BackendNonExposedDatabases"
    }
  }
}

# -----------------------------------------------------------------------------
# Network Configuration 
# -----------------------------------------------------------------------------


# HUB Network (1 VNet 10.0.0.0/22)
hub_vnet_config = {
  name          = "vnet-hub-POCpub-1"
  address_space = ["10.0.0.0/22"]
  tags = {
    Environment = "POC"
    Purpose     = "HubNetwork"
  }
}

# Spoke VNets - OnPrem Simulation + 2 Application Spokes
spoke_vnet_configs = {
  "onprem_simulation" = {
    name          = "vnet-onprem-POCpub-1"
    address_space = ["192.168.0.0/22"]
    tags = {
      Environment = "POC"
      Purpose     = "OnPremiseSimulation"
    }
  }
  "nonexpose" = {
    name          = "vnet-spoke-nonexpose-POCpub-1"
    address_space = ["10.1.0.0/24"]
    tags = {
      Environment = "POC"
      Purpose     = "SpokeNonExpose"
    }
  }
  "expose" = {
    name          = "vnet-spoke-expose-POCpub-1"
    address_space = ["10.2.0.0/24"]
    tags = {
      Environment = "POC"
      Purpose     = "SpokeExpose"
    }
  }
}

# EXACT SUBNET CONFIGURATION
subnet_configs = {
 "snet_sqlmi_nonexpose" = {
    name                   = "snet-sqlmi-nonexpose-POCpub-1"
    address_prefixes       = ["10.1.0.192/27"]  # /27 minimum for SQL MI (32 IPs)
    virtual_network_name   = "vnet-spoke-nonexpose-POCpub-1"
    network_security_group = "nsg-nonexpose-back-POCpub-1"
    route_table            = "rt-nonexpose-POCpub-1"
    
    # SQL MI delegation
    delegation = {
      name               = "sqlmi-delegation"
      service_delegation = "Microsoft.Sql/managedInstances"
    }
  }
  # OnPrem Subnets (1 subnet compute)
  "snet_onprem_compute" = {
    name                   = "snet-onprem-compute-POCpub-1"
    address_prefixes       = ["192.168.1.0/24"]
    virtual_network_name   = "vnet-onprem-POCpub-1"
    network_security_group = "nsg-onprem-compute-POCpub-1"
    route_table            = "rt-onprem-POCpub-1"
  }

  # HUB Subnets (3 imposés + 1 compute + 1 DNS)
  "snet_hub_firewall" = {
    name                 = "AzureFirewallSubnet"
    address_prefixes     = ["10.0.0.0/26"]
    virtual_network_name = "vnet-hub-POCpub-1"
  }

  "snet_hub_agw" = {
    name                   = "snet-hub-agw-POCpub-1"
    address_prefixes       = ["10.0.0.64/26"]
    virtual_network_name   = "vnet-hub-POCpub-1"
    network_security_group = "nsg-hub-agw-POCpub-1" # ✅ FIX: Assign AGW NSG
  }
  "snet_hub_bastion" = {
    name                 = "AzureBastionSubnet"
    address_prefixes     = ["10.0.0.128/27"]
    virtual_network_name = "vnet-hub-POCpub-1"
  }
  "snet_hub_compute" = {
    name                   = "snet-hub-compute-POCpub-1"
    address_prefixes       = ["10.0.0.160/27"]
    virtual_network_name   = "vnet-hub-POCpub-1"
    network_security_group = "nsg-hub-compute-POCpub-1"
  }
  "snet_hub_dns_inbound" = {
    name                 = "snet-hub-dns-inbound-POCpub-1"
    address_prefixes     = ["10.0.0.224/28"] # ✅ FIX: Use /28 minimum size (10.0.0.224-10.0.0.239)
    virtual_network_name = "vnet-hub-POCpub-1"
    delegation = {
      name               = "dns-resolver-delegation"
      service_delegation = "Microsoft.Network/dnsResolvers"
    }
  }
  "snet_hub_dns_outbound" = {
    name                 = "snet-hub-dns-outbound-POCpub-1"
    address_prefixes     = ["10.0.0.240/28"] # 
    virtual_network_name = "vnet-hub-POCpub-1"
    delegation = {
      name               = "dns-resolver-delegation"
      service_delegation = "Microsoft.Network/dnsResolvers"
    }
  }

  # Non-Exposé Spoke Subnets (3 subnets)
  "snet_integration_nonexpose" = {
    name                   = "snet-integration-nonexpose-POCpub-1"
    address_prefixes       = ["10.1.0.0/26"]
    virtual_network_name   = "vnet-spoke-nonexpose-POCpub-1"
    network_security_group = "nsg-nonexpose-front-POCpub-1"
    route_table            = "rt-nonexpose-POCpub-1"
    delegation = {
      name               = "webapp-delegation"
      service_delegation = "Microsoft.Web/serverFarms"
    }
  }
  "snet_pep_nonexpose" = {
    name                                          = "snet-pep-nonexpose-POCpub-1"
    address_prefixes                              = ["10.1.0.64/26"]
    virtual_network_name                          = "vnet-spoke-nonexpose-POCpub-1"
    network_security_group                        = "nsg-nonexpose-back-POCpub-1"
    route_table                                   = "rt-nonexpose-POCpub-1"
    private_endpoint_network_policies_enabled     = false
    private_link_service_network_policies_enabled = false

  }
  "snet_compute_nonexpose" = {
    name                   = "snet-compute-nonexpose-POCpub-1"
    address_prefixes       = ["10.1.0.160/27"]
    virtual_network_name   = "vnet-spoke-nonexpose-POCpub-1"
    network_security_group = "nsg-nonexpose-compute-POCpub-1"
    route_table            = "rt-nonexpose-POCpub-1"
  }

  # Exposé Spoke Subnets (3 subnets)
  "snet_integration_expose" = {
    name                   = "snet-integration-expose-POCpub-1"
    address_prefixes       = ["10.2.0.0/26"]
    virtual_network_name   = "vnet-spoke-expose-POCpub-1"
    network_security_group = "nsg-expose-front-POCpub-1"
    delegation = {
      name               = "webapp-delegation"
      service_delegation = "Microsoft.Web/serverFarms"
    }
  }
  "snet_pep_expose" = {
    name                                          = "snet-pep-expose-POCpub-1"
    address_prefixes                              = ["10.2.0.64/26"]
    virtual_network_name                          = "vnet-spoke-expose-POCpub-1"
    network_security_group                        = "nsg-expose-front-POCpub-1"
    private_endpoint_network_policies_enabled     = false
    private_link_service_network_policies_enabled = false
  }
  "snet_compute_expose" = {
    name                   = "snet-compute-expose-POCpub-1"
    address_prefixes       = ["10.2.0.128/25"]
    virtual_network_name   = "vnet-spoke-expose-POCpub-1"
    network_security_group = "nsg-expose-compute-POCpub-1"
    route_table            = "rt-expose-POCpub-1"
  }
  "snet_hub_nat" = {
    name                 = "snet-hub-nat-POCpub-1"
    address_prefixes     = ["10.0.1.0/26"] # ✅ NEW: Extend hub address space
    virtual_network_name = "vnet-hub-POCpub-1"
  }

}
# -----------------------------------------------------------------------------
# NSG Rules 
# -----------------------------------------------------------------------------
nsg_rules = {
  # OnPrem NSG - Updated for Bastion Access
  "nsg-onprem-compute-POCpub-1" = [
    {
      name                       = "Allow-RDP-From-Hub-Bastion"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "10.0.0.128/27"
      destination_address_prefix = "*"
      description                = "Allow RDP from Hub Bastion subnet"
    },
    {
      name                       = "Allow-SSH-From-Hub-Bastion"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "10.0.0.128/27"
      destination_address_prefix = "*"
      description                = "Allow SSH from Hub Bastion subnet"
    },
    {
      name                       = "Allow-SSH-From-Hub"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "10.0.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow SSH from Hub network"
    },
    {
      name                       = "Allow-RDP-From-Hub"
      priority                   = 210
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "10.0.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow RDP from Hub network"
    },
    {
      name                       = "Allow-HTTPS-From-Hub"
      priority                   = 220
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow HTTPS from Hub network"
    },
    {
      name                       = "Allow-HTTP-From-Hub"
      priority                   = 230
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow HTTP from Hub network"
    },
    {
      name                       = "Allow-Outbound-Internet"
      priority                   = 300
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "Internet"
      description                = "Allow outbound internet access"
    },
    {
      name                       = "Allow-Internal-Communication"
      priority                   = 400
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
      description                = "Allow communication within virtual networks"
    }
  ]

  # HUB Network NSGs - Appliqué sur les subnets
  "nsg-hub-compute-POCpub-1" = [
    {
      name                       = "Allow-RDP-From-Bastion"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "10.0.0.128/27"
      destination_address_prefix = "*"
      description                = "Subnet Compute => RDP from Bastion"
    },
    {
      name                       = "Allow-SSH-From-Bastion"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "10.0.0.128/27"
      destination_address_prefix = "*"
      description                = "Subnet Compute => SSH from Bastion"
    },
    {
      name                       = "Allow-HTTPS-Outbound"
      priority                   = 200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Allow HTTPS management traffic outbound"
    },
    {
      name                       = "Allow-HTTP-Outbound"
      priority                   = 210
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Allow HTTP management traffic outbound"
    },
    {
      name                       = "Deny-All-Other-Inbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Deny all other inbound"
    }
  ]

  # VNet app connectée non exposée - Subnet Front => Http
  "nsg-nonexpose-front-POCpub-1" = [
    {
      name                       = "Allow-HTTP-From-AppGateway"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "*"
      description                = "Subnet Front => Http from Application Gateway"
    },
    {
      name                       = "Allow-HTTPS-From-AppGateway"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "*"
      description                = "Subnet Front => HTTPS from Application Gateway"
    },
    {
      name                       = "Deny-Direct-Internet"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      description                = "Deny direct Internet access"
    },
    {
      name                       = "Allow-HTTP-From-AdminVM" # NEW
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.160/27" # Hub Admin-VM subnet
      destination_address_prefix = "*"
      description                = "Admin VM → Web-App PE (HTTP)"
    },
    {
      name                       = "Allow-HTTPS-From-AdminVM" # NEW
      priority                   = 121
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.160/27"
      destination_address_prefix = "*"
      description                = "Admin VM → Web-App PE (HTTPS)"
    }
  ]

  # VNet app connectée non exposée - Subnet Back => SQL MI with required network intent policy rules
# VNet app connectée non exposée - Subnet Back => SQL MI with COMPLETE network intent policy rules
"nsg-nonexpose-back-POCpub-1" = [
  {
    name                       = "Allow-SQL-From-Integration"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.1.0.0/26"
    destination_address_prefix = "*"
    description                = "Subnet Back => SQL + filtrage IP from Integration subnet"
  },
  {
    name                       = "Allow-HTTPS-PrivateEndpoint"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "Allow HTTPS for Private Endpoint traffic"
  },
  # ✅ COMPLETE SQL MI Network Intent Policy Rules
  {
    name                       = "Allow-Azure-LoadBalancer-HealthProbe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "10.1.0.192/27"
    description                = "Required for SQL MI health monitoring"
  },
  {
    name                       = "Allow-SqlMI-Internal-Inbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.192/27"
    destination_address_prefix = "10.1.0.192/27"
    description                = "Required for SQL MI internal communication"
  },
  # ✅ OUTBOUND RULES - All required for SQL MI
  {
    name                       = "Allow-SqlMI-AAD-Outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.1.0.192/27"
    destination_address_prefix = "AzureActiveDirectory"
    description                = "Required for SQL MI Azure AD authentication"
  },
  {
    name                       = "Allow-SqlMI-OneDsCollector-Outbound"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.1.0.192/27"
    destination_address_prefix = "OneDsCollector"
    description                = "Required for SQL MI telemetry"
  },
  {
    name                       = "Allow-SqlMI-Internal-Outbound"
    priority                   = 220
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.192/27"
    destination_address_prefix = "10.1.0.192/27"
    description                = "Required for SQL MI internal communication"
  },
  {
    name                       = "Allow-SqlMI-Storage-FranceCentral-Outbound"
    priority                   = 230
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.1.0.192/27"
    destination_address_prefix = "Storage.francecentral"
    description                = "Required for SQL MI storage access"
  },
  {
    name                       = "Allow-SqlMI-Storage-FranceSouth-Outbound"
    priority                   = 240
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.1.0.192/27"
    destination_address_prefix = "Storage.francesouth"
    description                = "Required for SQL MI storage access backup region"
  },
  # Admin/OnPrem access rules
  {
    name                       = "Allow-HTTP-From-AdminVM"
    priority                   = 250
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.0.0.160/27"
    destination_address_prefix = "*"
    description                = "Allow HTTP from Admin VM subnet to PE"
  },
  {
    name                       = "Allow-HTTPS-From-AdminVM"
    priority                   = 251
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.0.160/27"
    destination_address_prefix = "*"
    description                = "Allow HTTPS from Admin VM subnet to PE"
  },
  {
    name                       = "Allow-HTTP-From-OnPremVM"
    priority                   = 252
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "192.168.1.0/24"
    destination_address_prefix = "*"
    description                = "Allow HTTP from OnPrem VM subnet to PE"
  },
  {
    name                       = "Allow-HTTPS-From-OnPremVM"
    priority                   = 253
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "192.168.1.0/24"
    destination_address_prefix = "*"
    description                = "Allow HTTPS from OnPrem VM subnet to PE"
  },
  # ✅ REMOVED: Deny-All-Other rule - conflicts with SQL MI Network Intent Policy
  # SQL MI Network Intent Policy automatically manages security
]


  # Non-Exposé Compute NSG
  "nsg-nonexpose-compute-POCpub-1" = [
    {
      name                       = "Allow-SSH-From-Hub"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "10.0.0.160/27"
      destination_address_prefix = "*"
      description                = "Allow SSH from Hub compute"
    },
    {
      name                       = "Allow-RDP-From-Hub"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "10.0.0.160/27"
      destination_address_prefix = "*"
      description                = "Allow RDP from Hub compute"
    }
  ]

  # ✅ FIX: Application Gateway Subnet NSG - Required for AGW v2
  "nsg-hub-agw-POCpub-1" = [
    {
      name                       = "AllowGatewayManagerInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
      description                = "Allow Azure Gateway Manager inbound traffic (required for AGW v2)"
    },
    {
      name                       = "AllowInternetInbound"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      description                = "Allow HTTP from Internet"
    },
    {
      name                       = "AllowHTTPSInbound"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      description                = "Allow HTTPS from Internet"
    },
    {
      name                       = "AllowAzureLoadBalancerInbound"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
      description                = "Allow Azure Load Balancer health probes"
    },
    # ✅ ADD: Missing outbound rules for App Gateway
    {
      name                       = "AllowAppServiceOutbound"
      priority                   = 200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "10.2.0.0/26"
      description                = "Allow HTTP to Exposed Web-App PE"
    },
    {
      name                       = "AllowAppServiceHTTPSOutbound"
      priority                   = 210
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "10.2.0.0/26"
      description                = "Allow HTTPS to Exposed Web-App PE"
    },
    {
      name                       = "AllowNonExposedWebAppHTTP"
      priority                   = 240
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "10.1.0.0/26"
      description                = "Allow HTTP to Non-Exposed Web-App PE"
    },
    {
      name                       = "AllowNonExposedWebAppHTTPS"
      priority                   = 250
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "10.1.0.0/26"
      description                = "Allow HTTPS to Non-Exposed Web-App PE"
    },
    {
      name                       = "AllowDNSOutbound"
      priority                   = 220
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_range     = "53"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "168.63.129.16"
      description                = "Allow DNS queries to Azure DNS"
    }
  ]

  # VNet app connecté exposée - Subnet Front => Http (Internet via AGW + OnPrem via Firewall)
  "nsg-expose-front-POCpub-1" = [
      {
      name                       = "Allow-HTTPS-PrivateEndpoint"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
      description                = "Allow HTTPS for Private Endpoint traffic"
    },
    {
      name                       = "Allow-HTTP-From-AppGateway"
      priority                   = 105
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "*"
      description                = "Allow HTTP from Application Gateway (Internet traffic)"
    },
    {
      name                       = "Allow-HTTPS-From-AppGateway"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "*"
      description                = "Allow HTTPS from Application Gateway (Internet traffic)"
    },
    {
      name                       = "Allow-HTTP-OnPrem-via-Firewall"
      priority                   = 115
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow HTTP OnPrem traffic via Azure Firewall"
    },
    {
      name                       = "Allow-HTTPS-OnPrem-via-Firewall"
      priority                   = 116
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow HTTPS OnPrem traffic via Azure Firewall"
    },
    {
      name                       = "Allow-RDP-OnPrem-via-Firewall"
      priority                   = 117
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow RDP OnPrem traffic via Azure Firewall"
    },
    {
      name                       = "Allow-SSH-OnPrem-via-Firewall"
      priority                   = 118
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow SSH OnPrem traffic via Azure Firewall"
    },
    {
      name                       = "Allow-Outbound-NAT-Gateway"
      priority                   = 130
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Allow outbound to NAT Gateway"
    },
    {
      name                       = "Allow-HTTP-From-AdminVM" # NEW
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.160/27" # Hub Admin-VM subnet
      destination_address_prefix = "*"
      description                = "Admin VM → Web-App PE (HTTP)"
    },
    {
      name                       = "Allow-HTTPS-From-AdminVM" # NEW
      priority                   = 121
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.160/27"
      destination_address_prefix = "*"
      description                = "Admin VM → Web-App PE (HTTPS)"
    },

    {
      name                       = "Deny-Direct-Internet-Inbound"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      description                = "Deny direct Internet inbound (must use AGW)"
    }
  ]

  # VNet app connecté exposée - Subnet Back => SQL + filtrage IP
  "nsg-expose-back-POCpub-1" = [
    {
      name                       = "Allow-SQL-From-Integration"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1433"
      source_address_prefix      = "10.2.0.0/26"
      destination_address_prefix = "*"
      description                = "Subnet Back => SQL + filtrage IP from Integration subnet"
    },
  
    # Removed duplicate AdminVM/OnPremVM HTTP/HTTPS rules (present in nonexpose-back NSG)
    {
      name                       = "Deny-All-Other"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Deny all other traffic"
    }
  ]

  # Exposé Compute NSG - Enhanced for OnPrem and Database Access
  "nsg-expose-compute-POCpub-1" = [
    {
      name                       = "Allow-SSH-From-Hub"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "10.0.0.160/27"
      destination_address_prefix = "*"
      description                = "Allow SSH from Hub compute"
    },
    {
      name                       = "Allow-RDP-From-Hub"
      priority                   = 101
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "10.0.0.160/27"
      destination_address_prefix = "*"
      description                = "Allow RDP from Hub compute"
    },
    {
      name                       = "Allow-HTTP-OnPrem-Access"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow HTTP OnPrem access via Azure Firewall"
    },
    {
      name                       = "Allow-HTTPS-OnPrem-Access"
      priority                   = 111
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow HTTPS OnPrem access via Azure Firewall"
    },
    {
      name                       = "Allow-RDP-OnPrem-Access"
      priority                   = 112
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow RDP OnPrem access via Azure Firewall"
    },
    {
      name                       = "Allow-SSH-OnPrem-Access"
      priority                   = 113
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "192.168.0.0/22"
      destination_address_prefix = "*"
      description                = "Allow SSH OnPrem access via Azure Firewall"
    },
    {
      name                       = "Allow-HTTP-AGW-Health-Probe"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "*"
      description                = "Allow HTTP Application Gateway health probes"
    },
    {
      name                       = "Allow-HTTPS-AGW-Health-Probe"
      priority                   = 121
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.64/26"
      destination_address_prefix = "*"
      description                = "Allow HTTPS Application Gateway health probes"
    },
    {
      name                       = "Allow-Outbound-SQL"
      priority                   = 200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1433"
      source_address_prefix      = "*"
      destination_address_prefix = "10.2.0.64/26"
      description                = "Allow outbound SQL to database subnet"
    },
    {
      name                       = "Allow-Outbound-HTTPS-Database"
      priority                   = 201
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "10.2.0.64/26"
      description                = "Allow outbound HTTPS to database subnet"
    },
    {
      name                       = "Allow-Outbound-Internet"
      priority                   = 210
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "Internet"
      description                = "Allow outbound internet via NAT Gateway"
    },
    {
      name                       = "Allow-Outbound-VNet"
      priority                   = 220
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
      description                = "Allow communication within virtual networks"
    }
  ]
}

# -----------------------------------------------------------------------------
# Route Tables - UDR Implementation 
# -----------------------------------------------------------------------------
route_tables = {
  # OnPrem Route Table: On-prem -> Hub -> Firewall -> Non-Connected Apps
  "rt-onprem-POCpub-1" = {
    routes = [
      {
        name                   = "Route-to-NonExpose-Spoke"
        address_prefix         = "10.1.0.0/24"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.0.0.4"
      },
      {
        name                   = "Route-to-Expose-Spoke-via-Firewall"
        address_prefix         = "10.2.0.0/24"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.0.0.4"
      },
      {
        name                   = "Route-to-Hub"
        address_prefix         = "10.0.0.0/22"
        next_hop_type          = "VnetLocal"
        next_hop_in_ip_address = null
      }
    ]
    tags = {
      Environment = "POC"
      Purpose     = "OnPrem-via-Firewall-to-NonConnectedApps"
    }
  }
  # Non-Exposé Route Table: AFW -> Next Hop -> Vnet Spoke App connectée non expo with SQL MI requirements
# Non-Exposé Route Table: AFW -> Next Hop -> Vnet Spoke App connectée non expo with COMPLETE SQL MI requirements
"rt-nonexpose-POCpub-1" = {
  routes = [
   {
      name                   = "Route-to-AAD"
      address_prefix         = "AzureActiveDirectory"
      next_hop_type          = "Internet"
      next_hop_in_ip_address = null
    },
    {
      name                   = "Route-to-OneDsCollector"
      address_prefix         = "OneDsCollector"
      next_hop_type          = "Internet"
      next_hop_in_ip_address = null
    },
    {
      name                   = "Route-to-Storage-FranceCentral"
      address_prefix         = "Storage.francecentral"
      next_hop_type          = "Internet"
      next_hop_in_ip_address = null
    },
    {
      name                   = "Route-to-Storage-FranceSouth"
      address_prefix         = "Storage.francesouth"
      next_hop_type          = "Internet"
      next_hop_in_ip_address = null
    },
    {
      name                   = "SqlMI-Subnet-Local"
      address_prefix         = "10.1.0.192/27"
      next_hop_type          = "VnetLocal"
      next_hop_in_ip_address = null
    },
    {
      name                   = "Default-Route-via-AFW"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = "10.0.0.4"
    },
    {
      name                   = "Route-to-OnPrem"
      address_prefix         = "192.168.0.0/22"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = "10.0.0.4"
    },
    {
      name                   = "Route-to-Expose-Spoke"
      address_prefix         = "10.2.0.0/24"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = "10.0.0.4"
    }
  ]
  tags = {
    Environment = "POC"
    Purpose     = "AFW-NextHop-NonExpose-SqlMI"
  }
}


  # Exposé Route Table: Sortie Internet NAT GW
  "rt-expose-POCpub-1" = {
    routes = [
      {
        name                   = "Default-Route-via-NAT-Gateway"
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "Internet"
        next_hop_in_ip_address = null
      },
      {
        name                   = "Route-to-OnPrem"
        address_prefix         = "192.168.0.0/22"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.0.0.4"
      },
      {
        name                   = "Route-to-NonExpose-Spoke"
        address_prefix         = "10.1.0.0/24"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.0.0.4"
      }
    ]
    tags = {
      Environment = "POC"
      Purpose     = "NAT-Gateway-Internet-Exit"
    }
  }
  # Application Gateway Route Table: AGW -> Backend pool -> App connectée exposée
  "rt-agw-POCpub-1" = {
    routes = [
      {
        name                   = "Route-to-Expose-Backend"
        address_prefix         = "10.2.0.0/26"
        next_hop_type          = "VnetLocal"
        next_hop_in_ip_address = null
      }
    ]
    tags = {
      Environment = "POC"
      Purpose     = "AGW-to-Backend-Pool"
    }
  }
  # Hub Default Route Table - Updated for Peering
  "rt-hub-default-POCpub-1" = {
    routes = [
      {
        name                   = "Route-to-OnPrem-via-Peering"
        address_prefix         = "192.168.0.0/22"
        next_hop_type          = "VnetLocal"
        next_hop_in_ip_address = null
      }
    ]
    tags = {
      Environment = "POC"
      Purpose     = "Hub-Default-Routing-Peering"
    }
  }
}

# -----------------------------------------------------------------------------
# VPN Gateway Configuration (OnPrem <-> Hub Network)
# -----------------------------------------------------------------------------
vpn_gateway_config = null

# ExpressRoute Gateway (if needed instead of VPN)
expressroute_gateway_config = null

# Bastion Host Configuration
bastion_host_config = {
  name       = "bas-hub-POCpub-1"
  subnet_key = "snet_hub_bastion"
  tags = {
    Environment = "POC"
    Purpose     = "SecureAccess_AdminVM_Only"
  }
}

# Private Endpoint Configs
private_endpoint_configs = {}

# Flow Log Configuration - Set to null to use default NSG flow log configuration
flow_log_config = null

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

# Key Vault
key_vault_config = {
  name                            = "kv-shared-POCpub-1"
  sku_name                        = "standard"
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  enable_rbac_authorization       = false # ✅ CRITICAL: Use access policies for POC reliability
  soft_delete_retention_days      = 7
  purge_protection_enabled        = true # ✅ REQUIRED: Enable for DES functionality (Azure requirement)
  access_policies                 = []   # Will be auto-populated with current user permissions
  tags = {
    Environment = "POC"
    Purpose     = "SharedSecrets"
  }
}

# Encryption Keys
encryption_keys = {
  "vm_encryption_key" = {
    name     = "vm-encryption-key-v2" # ✅ FIX: Changed name to avoid soft-deleted key conflict
    key_type = "RSA"
    key_size = 2048
    key_opts = [
      "decrypt",
      "encrypt",
      "sign",
      "unwrapKey",
      "verify",
      "wrapKey"
    ]
    tags = {
      Environment = "POC"
      Purpose     = "VMDiskEncryption"
    }
  }
  "storage_encryption_key" = {
    name     = "storage-encryption-key-v2" # ✅ FIX: Changed name to avoid soft-deleted key conflict
    key_type = "RSA"
    key_size = 2048
    key_opts = [
      "decrypt",
      "encrypt",
      "unwrapKey",
      "wrapKey"
    ]
    tags = {
      Environment = "POC"
      Purpose     = "StorageEncryption"
    }
  }
  "sqlmi_tde_key" = {
    name     = "sqlmi-tde-key-v2" # ✅ FIX: Changed name to avoid soft-deleted key conflict
    key_type = "RSA"
    key_size = 2048
    key_opts = [
      "decrypt",
      "encrypt",
      "unwrapKey",
      "wrapKey"
    ]
    tags = {
      Environment = "POC"
      Purpose     = "SQLMITransparentDataEncryption"
    }
  }
}

# Key Vault Secrets
key_vault_secrets = {
  "vm-admin-password" = {
    name  = "vm-admin-password"
    value = "AdminP@ssw0rd1234!"
    tags = {
      Purpose = "VMAdministration"
    }
  }
  "sqlmi-admin-password" = {
    name  = "sqlmi-admin-password"
    value = "SqlP@ssw0rd1234!"
    tags = {
      Purpose = "DatabaseAdministration"
    }
  }
}


# WAF Policy Configuration
waf_policy_config = {
  name = "wafpol-hub-POCpub-1"
  tags = {
    Environment = "POC"
    Purpose     = "WebApplicationProtection"
  }
}

# -----------------------------------------------------------------------------
# Identity Configuration
# -----------------------------------------------------------------------------

# Managed Identities - Distributed by purpose
managed_identities = {
  "msi_storage_shared" = {
    name                = "msi-storage-shared-POCpub-1"
    resource_group_name = "network-hub"
    location            = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "SharedStorageEncryption"
    }
  }
  "msi_fe_nonexposed" = {
    name                = "msi-fe-nonexposed-POCpub-1"
    resource_group_name = "fe-non-exposed-connected-apps" # ✅ MATCHES: rg_fe_nonexposed_apps.name
    location            = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "NonExposedAppServices"
    }
  }
  "msi_fe_exposed" = {
    name                = "msi-fe-exposed-POCpub-1"
    resource_group_name = "fe-exposed-connected-apps" # ✅ MATCHES: rg_fe_exposed_apps.name
    location            = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "ExposedAppServices"
    }
  }
}

# Custom RBAC Roles
custom_roles = {
  "vm_operator" = {
    name        = "VM Operator Azure POC"
    description = "Can start, stop, and restart virtual machines"
    permissions = [
      {
        actions = [
          "Microsoft.Compute/virtualMachines/start/action",
          "Microsoft.Compute/virtualMachines/restart/action",
          "Microsoft.Compute/virtualMachines/deallocate/action",
          "Microsoft.Compute/virtualMachines/read",
          "Microsoft.Resources/subscriptions/resourceGroups/read"
        ]
        not_actions      = []
        data_actions     = []
        not_data_actions = []
      }
    ]
    assignable_scopes = ["/subscriptions/7445ae6f-a879-4d74-9a49-eebda848dc6c"]
  }
}

# Role Assignments
role_assignments = {
  "admin_key_vault_access" = {
    scope                = "/subscriptions/7445ae6f-a879-4d74-9a49-eebda848dc6c"
    role_definition_name = "Key Vault Administrator"
    role_definition_id   = null
    principal_id         = "placeholder-will-be-replaced-by-data-source"
  }
  # ✅ ADDITIONAL: Crypto roles for comprehensive Key Vault access
  "admin_key_vault_crypto_admin" = {
    scope                = "/subscriptions/7445ae6f-a879-4d74-9a49-eebda848dc6c"
    role_definition_name = "Key Vault Crypto Officer"
    role_definition_id   = null
    principal_id         = "placeholder-will-be-replaced-by-data-source"
  }
}

# Identity Providers
identity_providers = {
  "poc_oidc_app" = {
    name          = "POC-OIDC-Demo-App"
    redirect_uris = ["https://webapp-expose-pocpub-1.azurewebsites.net/signin-oidc"]
    required_resource_access = {
      resource_app_id = "00000003-0000-0000-c000-000000000000"
      resource_access = {
        id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
        type = "Scope"
      }
    }
    type = "OIDC"
  }
}

application_owner_object_id = "a1b2c3d4-e5f6-7890-ab12-cd34ef567890"

# -----------------------------------------------------------------------------
# Monitoring Configuration - Network Watcher → LAW
# -----------------------------------------------------------------------------

workspace_config = {
  name              = "law-network-POCpub-1"
  sku               = "PerGB2018"
  retention_in_days = 90
  tags = {
    Environment = "POC"
    Purpose     = "NetworkWatcher_NSGFlows_FirewallLogs"
  }
}

action_groups = {
  "ag_network_alerts" = {
    name       = "ag-network-alerts-poc"
    short_name = "ag-net"
    email_receivers = [
      {
        name          = "admin-email"
        email_address = "maeva@MngEnvMCAP334656.onmicrosoft.com"
      }
    ]
    tags = {
      Environment = "POC"
      Purpose     = "NetworkMonitoring"
    }
  }
}

# Network-focused metric alerts
metric_alerts = {
  "firewall_throughput_alert" = {
    name                = "alert-firewall-throughput-high"
    resource_group_name = "network-hub"
    scopes              = ["/subscriptions/7445ae6f-a879-4d74-9a49-eebda848dc6c/resourceGroups/network-hub"]
    description         = "High throughput on Azure Firewall"
    criteria = {
      metric_namespace = "Microsoft.Network/azureFirewalls"
      metric_name      = "Throughput"
      aggregation      = "Average"
      operator         = "GreaterThan"
      threshold        = 1000000000
    }
    frequency        = "PT5M"
    window_size      = "PT15M"
    severity         = 2
    action_group_ids = ["ag_network_alerts"]
  }
  "agw_response_time_alert" = {
    name                = "alert-agw-response-time-high"
    resource_group_name = "network-hub"
    scopes              = ["/subscriptions/7445ae6f-a879-4d74-9a49-eebda848dc6c/resourceGroups/network-hub"]
    description         = "High response time on Application Gateway"
    criteria = {
      metric_namespace = "Microsoft.Network/applicationGateways"
      metric_name      = "ApplicationGatewayTotalTime"
      aggregation      = "Average"
      operator         = "GreaterThan"
      threshold        = 5000
    }
    frequency        = "PT1M"
    window_size      = "PT5M"
    severity         = 1
    action_group_ids = ["ag_network_alerts"]
  }
}

# Service Health Alerts
service_health_alerts = {
  "service_health_critical" = {
    name    = "alert-service-health-critical"
    enabled = true
    scopes  = ["/subscriptions/7445ae6f-a879-4d74-9a49-eebda848dc6c"]
    criteria = {
      service_health = [
        {
          locations = ["France Central", "Global"]
          events    = ["Incident", "Maintenance"]
        }
      ]
    }
    action_group_ids = ["ag_network_alerts"]
    tags = {
      Environment = "POC"
      Criticality = "High"
    }
  }
}

# Network-focused diagnostic settings
diagnostic_settings = {}

# Data collection rules for network monitoring
data_collection_rules = {
  "dcr_network_monitoring" = {
    name = "dcr-network-monitoring-POCpub-1"
    destinations = [
      {
        name                  = "law-destination"
        workspace_resource_id = "/subscriptions/7445ae6f-a879-4d74-9a49-eebda848dc6c/resourceGroups/network-hub/providers/Microsoft.OperationalInsights/workspaces/law-network-POCpub-1"
      }
    ]
    data_sources = {
      windows_event_log = [
        {
          name           = "Security-Events"
          streams        = ["Microsoft-SecurityEvent"]
          x_path_queries = ["Security!*[System[(EventID=4624)]]"]
        }
      ]
    }
    tags = {
      Environment = "POC"
      Purpose     = "NetworkSecurityMonitoring"
    }
  }
}

query_alerts = {}

# -----------------------------------------------------------------------------
# Storage Configuration
# -----------------------------------------------------------------------------

storage_accounts = {
  # ✅ SHARED STORAGE (Network Hub)
  "st_shared_data" = {
    name                            = "stsharedpocpub1"
    account_tier                    = "Standard"
    account_replication_type        = "LRS"
    account_kind                    = "StorageV2"
    access_tier                     = "Hot"
    versioning_enabled              = false
    blob_soft_delete_retention_days = 7
    allow_shared_key_access         = true
    tags = {
      Environment = "POC"
      Purpose     = "SharedData"
    }
  }
  "st_flowlogs" = {
    name                            = "stflowlogspocpub1"
    account_tier                    = "Standard"
    account_replication_type        = "LRS"
    account_kind                    = "StorageV2"
    access_tier                     = "Cool"
    versioning_enabled              = false
    blob_soft_delete_retention_days = 30
    allow_shared_key_access         = true
    tags = {
      Environment = "POC"
      Purpose     = "NetworkFlowLogs"
    }
  }

  # ✅ NON-EXPOSED BACKEND STORAGE
  "st_nonexposed_data" = {
    name                            = "stnonexposedpocpub1"
    account_tier                    = "Standard"
    account_replication_type        = "LRS"
    account_kind                    = "StorageV2"
    access_tier                     = "Hot"
    versioning_enabled              = false
    blob_soft_delete_retention_days = 7
    allow_shared_key_access         = true
    tags = {
      Environment = "POC"
      Purpose     = "NonExposedAppData"
    }
  }

  # ✅ EXPOSED BACKEND STORAGE
  "st_exposed_data" = {
    name                            = "stexposedpocpub1"
    account_tier                    = "Standard"
    account_replication_type        = "LRS"
    account_kind                    = "StorageV2"
    access_tier                     = "Hot"
    versioning_enabled              = false
    blob_soft_delete_retention_days = 7
    allow_shared_key_access         = true
    tags = {
      Environment = "POC"
      Purpose     = "ExposedAppData"
    }
  }
}

storage_containers = {
  # ✅ SHARED CONTAINERS (Network Hub)
  "container_shared_data" = {
    name                    = "shareddata"
    storage_account_key_ref = "st_shared_data"
    container_access_type   = "private"
  }
  "container_flow_logs" = {
    name                    = "flowlogs"
    storage_account_key_ref = "st_flowlogs"
    container_access_type   = "private"
  }

  # ✅ NON-EXPOSED CONTAINERS
  "container_nonexposed_data" = {
    name                    = "nonexposeddata"
    storage_account_key_ref = "st_nonexposed_data"
    container_access_type   = "private"
  }

  # ✅ EXPOSED CONTAINERS
  "container_exposed_data" = {
    name                    = "exposeddata"
    storage_account_key_ref = "st_exposed_data"
    container_access_type   = "private"
  }
}

# Recovery Services Vault
recovery_services_vault_config = {
  name                = "rsv-backup-POCpub-1"
  sku                 = "Standard"
  soft_delete_enabled = false # ✅ CRITICAL: Disable for smooth destroy
  tags = {
    Environment = "POC"
    Purpose     = "BackupAndRecovery"
  }
}

# VM Backup Policy
backup_policies_vm = {
  "policy_daily_vm" = {
    name = "policy-daily-vm-backup"
    backup = {
      frequency = "Daily"
      time      = "23:00"
    }
    retention_daily = {
      count = 7
    }
    retention_weekly = {
     
      count    = 4
      weekdays = ["Sunday"]
    }
    retention_monthly = {
      count    = 3
      weekdays = ["Sunday"]
      weeks    = ["First"]
    }
    retention_yearly = {
      count    = 1
      weekdays = ["Sunday"]
      weeks    = ["First"]
      months   = ["January"]
    }
  }
}

# VMs to backup
vms_to_backup = {
  "admin_vm_backup" = {
    vm_name             = "vm-admin-POCpub-1"
    backup_policy_name  = "policy_daily_vm"
    resource_group_name = "network-hub"
  }
}

managed_disks        = {}
site_recovery_config = null

# -----------------------------------------------------------------------------
# Compute Configuration - VM Admin dans le HUB network
# -----------------------------------------------------------------------------

# Disk Encryption Set Configuration
disk_encryption_set_config = {
  name_prefix = "des-vmdisk-POCpub-1"
  tags = {
    Environment = "POC"
    Purpose     = "DiskEncryption"
  }
}


# Windows VM Admin (accessible uniquement via Azure Bastion)
windows_vms = {
  admin_vm = {
    name_prefix    = "vm-admin-POCpub-1"
    computer_name  = "ADMIN01"
    size           = "Standard_D4als_v6"
    admin_username = "pocadmin"
    admin_password = "AdminP@ssw0rd1234!"
    subnet_name    = "snet_hub_compute"
    source_image_reference = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
    }
    data_disks = [
      {
        name                 = "data-disk-admin"
        lun                  = 0
        caching              = "ReadWrite"
        storage_account_type = "Premium_LRS"
        disk_size_gb         = 64
        create_option        = "Empty"
      }
    ]
    enable_azure_monitor_agent = true
    tags = {
      Environment = "POC"
      Purpose     = "AdminVM_Bastion_Only"
      Backup      = "Daily"
    }
  }

  vm_frontapp2_nonexpose = {
    name_prefix    = "vm-frontapp2-nonexpose-POCpub-1"
    computer_name  = "FRONT2NE"
    size           = "Standard_D4als_v6"
    admin_username = "pocadmin"
    admin_password = "AdminP@ssw0rd1234!"
    subnet_name    = "snet_compute_nonexpose"
    source_image_reference = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
    data_disks                 = []
    enable_azure_monitor_agent = true
    tags = {
      Environment = "POC"
      Purpose     = "FrontApp2_VM_NonExpose"
    }
  }

  vm_frontapp2_expose = {
    name_prefix    = "vm-frontapp2-expose-POCpub-1"
    computer_name  = "FRONT2EX"
    size           = "Standard_D4als_v6"
    admin_username = "pocadmin"
    admin_password = "AdminP@ssw0rd1234!"
    subnet_name    = "snet_compute_expose"
    source_image_reference = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
    data_disks                 = []
    enable_azure_monitor_agent = true
    tags = {
      Environment = "POC"
      Purpose     = "FrontApp2_VM_Expose"
    }
  }

  vm_onprem_server = {
    name_prefix    = "vm-onprem-server-POCpub-1"
    computer_name  = "ONPREM01"
    size           = "Standard_D4als_v6"
    admin_username = "onpremadmin"
    admin_password = "OnPremP@ssw0rd1234!"
    subnet_name    = "snet_onprem_compute"
    source_image_reference = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
    }
    data_disks = [
      {
        name                 = "data-disk-onprem"
        lun                  = 0
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
        disk_size_gb         = 32
        create_option        = "Empty"
      }
    ]
    enable_azure_monitor_agent = true
    tags = {
      Environment = "POC"
      Purpose     = "OnPrem_Simulation_Server"
      Location    = "OnPremise_Simulated"
    }
  }
}
# Linux VMs (None required for this architecture)
linux_vms = {}

# VM Extensions - OnPrem RDP Configuration and Diagnostics
vm_extensions_raw = {
  "onprem_rdp_config" = {
    name                 = "OnPremRDPConfiguration"
    virtual_machine_name = "vm_onprem_server"
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.10"
    settings_object = {
      commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"& { Write-Host 'Starting OnPrem VM RDP Configuration...'; Set-Service -Name TermService -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name TermService -ErrorAction SilentlyContinue; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp' -Name 'UserAuthentication' -Value 1 -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'Allow-RDP-Bastion' -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -RemoteAddress 10.0.0.128/27 -Force -ErrorAction SilentlyContinue; netsh advfirewall firewall set rule group='remote desktop' new enable=Yes; Write-Host 'OnPrem VM RDP Configuration completed successfully'; Get-Service TermService | Format-List Name,Status,StartType; Get-NetFirewallRule -DisplayName '*Remote Desktop*' | Select-Object DisplayName,Enabled,Direction | Format-Table }\""
    }
    tags = {
      Purpose = "OnPremRDPAndDiagnostics"
      VM      = "OnPremServer"
    }
  }
}

# -----------------------------------------------------------------------------
# WEB APPLICATIONS CONFIGURATION
# -----------------------------------------------------------------------------

# ✅ WEB APP SERVICE PLANS
app_service_plans = {
  "asp_fe_exposed" = {
    name                = "asp-fe-exposed-POCpub-1"
    resource_group_name = "fe-exposed-connected-apps" # ✅ REQUIRED
    location            = "France Central"            # ✅ REQUIRED  
    os_type             = "Windows"
    sku_name            = "S1"
    tags = {
      Environment = "POC"
      Purpose     = "FrontendExposedApps"
    }
  }
  "asp_fe_nonexposed" = {
    name                = "asp-fe-nonexposed-POCpub-1"
    resource_group_name = "fe-non-exposed-connected-apps" # ✅ REQUIRED
    location            = "France Central"                # ✅ REQUIRED
    os_type             = "Windows"
    sku_name            = "S1"
    tags = {
      Environment = "POC"
      Purpose     = "FrontendNonExposedApps"
    }
  }
}




# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

# SQL Managed Instance for Non-Exposé (Backend App 1)
# ✅ SQL MI Configuration

#ajouter un vnet integration for sql instance
enable_sql_mi = true
mi_subnet_key = "snet_sqlmi_nonexpose"

mi_settings = {
  name_prefix                  = "sqlmi-nonexpose-pocpub-1"
  sku_name                     = "GP_Gen5"
  vcores                       = 4
  storage_size_in_gb           = 32
  administrator_login          = "sqladmin"
  administrator_login_password = "SqlP@ssw0rd1234!"
  public_data_endpoint_enabled = false
  collation                    = "SQL_Latin1_General_CP1_CI_AS"
  license_type                 = "LicenseIncluded"
  proxy_override               = "Proxy"
  timezone_id                  = "UTC"
  minimal_tls_version          = "1.2"
  # ✅ TEMPORARILY DISABLED: TDE with CMK causes destroy issues
  # transparent_data_encryption_key_vault_key_id = "sqlmi_tde_key"
  tags = {
    Environment = "POC"
    Purpose     = "BackendApp1_Database_NonExpose"
    Backup      = "Automated"
  }
}

# Private Endpoint Configuration for SQL MI
# ✅ REMOVED: SQL MI with subnet delegation already provides private connectivity
# Private endpoints cannot be created on delegated subnets
private_endpoint_config = null
