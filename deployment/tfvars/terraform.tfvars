
# Basic Configuration
# -----------------------------------------------------------------------------
location = "France Central"

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
    address_prefixes       = ["10.1.0.192/27"] # /27 minimum for SQL MI (32 IPs)
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
# WEB APPLICATIONS CONFIGURATION
# -----------------------------------------------------------------------------
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

web_apps = {
  webapp_exposed = {
    name                = "webapp-expose-pocpub-1"
    resource_group_name = "fe-exposed-connected-apps"
    location            = "France Central"
    service_plan_key    = "asp_fe_exposed"

    os_type                       = "Windows"
    https_only                    = false
    public_network_access_enabled = true # ✅ REQUIRED for App Gateway

    vnet_integration_enabled = true
    vnet_integration_subnet  = "snet_integration_expose"

    private_endpoint_enabled = true
    private_endpoint_subnet  = "snet_pep_expose"

    # ✅ STRICT IP RESTRICTIONS: Only App Gateway allowed
    ip_restrictions = [
      {
        name       = "AllowAppGatewaySubnet"
        ip_address = "10.0.0.64/26" # App Gateway subnet
        priority   = 100
        action     = "Allow"
      },
      {
        name       = "DenyAllOther"
        ip_address = "0.0.0.0/0" # Deny everything else
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
