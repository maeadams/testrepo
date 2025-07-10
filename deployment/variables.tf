variable "location" {
  description = "The Azure region for all resources.."
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