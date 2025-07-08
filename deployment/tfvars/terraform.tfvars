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

