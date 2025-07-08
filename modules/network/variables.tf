variable "resource_group_name" {
  description = "The name of the resource group where primary network resources like Network Watcher will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region where primary network resources will be deployed."
  type        = string
}

variable "eventgrid_source_arm_resource_id" {
  description = "The ARM resource ID for the Event Grid System Topic source (e.g., Storage Account ID)"
  type        = string
  default     = null # Making it optional
}

variable "hub_vnet_config" {
  description = "Hub VNet configuration"
  type = object({
    name          = string
    address_space = list(string)
    tags          = optional(map(string))
  })
}

variable "spoke_vnet_configs" {
  description = "Spoke VNet configurations"
  type = map(object({
    name          = string
    address_space = list(string)
    tags          = optional(map(string))
  }))
}

variable "subnet_configs" {
  description = "Subnet CIDR blocks and settings"
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
}

variable "nsg_rules" {
  description = "Network security rules definitions, keyed by NSG name"
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
  description = "Custom route configurations, keyed by Route Table name"
  type = map(object({
    routes = list(object({
      name                   = string
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    }))
    tags                          = optional(map(string))
    disable_bgp_route_propagation = optional(bool, false) # Restoring as it's a valid attribute
  }))
  default = {}
}





variable "vpn_gateway_config" {
  description = "VPN Gateway configuration"
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

variable "private_endpoint_configs" {
  description = "Private endpoint configurations"
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

variable "bastion_host_config" {
  description = "Azure Bastion Host configuration."
  type = object({
    name          = string
    subnet_key    = string #   ADD: Key to look up subnet in subnet_configs
    public_ip_sku = optional(string, "Standard")
    tags          = optional(map(string))
  })
  default = null
}

# ADD: ExpressRoute Gateway variable
variable "expressroute_gateway_config" {
  description = "ExpressRoute Gateway configuration"
  type = object({
    name       = string
    sku        = string
    subnet_key = string
    tags       = optional(map(string))
  })
  default = null
}
