# Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_config.name
  address_space       = var.hub_vnet_config.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.hub_vnet_config.tags
}

# Spoke Virtual Networks
resource "azurerm_virtual_network" "spoke" {
  for_each            = var.spoke_vnet_configs
  name                = each.value.name
  address_space       = each.value.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = each.value.tags
}

# Subnets - with explicit dependencies
resource "azurerm_subnet" "subnet" {
  for_each             = var.subnet_configs
  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = each.value.virtual_network_name
  address_prefixes     = each.value.address_prefixes

  # ✅ REMOVED: Don't set these inline - use separate association resources
  # network_security_group_id = try(azurerm_network_security_group.nsg[each.value.network_security_group].id, null)
  # route_table_id           = try(azurerm_route_table.route_table[each.value.route_table].id, null)

  # Keep other properties
  service_endpoints                             = lookup(each.value, "service_endpoints", null)
  private_link_service_network_policies_enabled = lookup(each.value, "private_link_service_network_policies_enabled", null)

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", null) != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name = delegation.value.service_delegation
        # ✅ REMOVED: actions - they are automatic for service delegation
      }
    }
  }

  # ✅ ADD: Prevent constant recreation
  lifecycle {
    ignore_changes = [
      service_endpoints,
    ]
  }

  depends_on = [
    azurerm_virtual_network.hub,
    azurerm_virtual_network.spoke
  ]
}

# Network Security Groups
resource "azurerm_network_security_group" "nsg" {
  for_each            = { for k, v_list in var.nsg_rules : k => v_list }
  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.hub_vnet_config.tags

  dynamic "security_rule" {
    for_each = each.value
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
      description                = lookup(security_rule.value, "description", null)
    }
  }
}

# Route Tables
resource "azurerm_route_table" "route_table" {
  for_each            = var.route_tables
  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  # disable_bgp_route_propagation removed as per user instruction, despite documentation suggesting it's valid.
  tags = lookup(each.value, "tags", null)

  dynamic "route" {
    for_each = each.value.routes
    content {
      name                   = route.value.name
      address_prefix         = route.value.address_prefix
      next_hop_type          = route.value.next_hop_type
      next_hop_in_ip_address = lookup(route.value, "next_hop_in_ip_address", null)
    }
  }
}

# Associate NSGs to Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  for_each = {
    for k, v in var.subnet_configs : k => v
    if lookup(v, "network_security_group", null) != null
  }

  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.value.network_security_group].id

  # ✅ PREVENT: Recreation due to case sensitivity in Azure resource IDs
  lifecycle {
    ignore_changes = [
      subnet_id # Ignore case differences in resource IDs from Azure API
    ]
  }

  depends_on = [
    azurerm_subnet.subnet,
    azurerm_network_security_group.nsg
  ]
}

# Associate Route Tables to Subnets
resource "azurerm_subnet_route_table_association" "rt_assoc" {
  for_each = {
    for k, v in var.subnet_configs : k => v
    if lookup(v, "route_table", null) != null
  }

  subnet_id      = azurerm_subnet.subnet[each.key].id
  route_table_id = azurerm_route_table.route_table[each.value.route_table].id

  # ✅ PREVENT: Recreation due to case sensitivity in Azure resource IDs
  lifecycle {
    ignore_changes = [
      subnet_id,     # Ignore case differences in resource IDs from Azure API
      route_table_id # Ignore case differences in resource IDs from Azure API
    ]
  }

  depends_on = [
    azurerm_subnet.subnet,
    azurerm_route_table.route_table
  ]
}

# ✅ REMOVED: Network Watcher data source (not always available)
# Network Watcher is created automatically by Azure when needed



# VPN Gateway Public IP
resource "azurerm_public_ip" "vpn_gateway_pip" {
  count = var.vpn_gateway_config != null ? 1 : 0

  name                = "pip-${var.vpn_gateway_config.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = lookup(var.vpn_gateway_config, "tags", null)
}


# ✅ FIXED: Use static values for Private DNS Zones
locals {
  dns_zones = toset([
    "privatelink.database.windows.net",
    "privatelink.redis.cache.windows.net",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.azurewebsites.net"
  ])
}

resource "azurerm_private_dns_zone" "private_dns_zones" {
  for_each = local.dns_zones

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = { "Environment" = "POC", "Purpose" = "PrivateEndpoints" }
}

# ✅ CRITICAL: Ensure private DNS zone resolution works correctly
resource "azurerm_private_dns_zone_virtual_network_link" "hub_dns_links" {
  for_each = local.dns_zones

  name                  = "link-hub-${replace(each.key, ".", "-")}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false # ✅ CRITICAL: False for manual private endpoint DNS
  tags                  = { "Environment" = "POC" }

  depends_on = [azurerm_private_dns_zone.private_dns_zones]
}

# ✅ CRITICAL: Spoke DNS links for private endpoint resolution
resource "azurerm_private_dns_zone_virtual_network_link" "spoke_dns_links" {
  for_each = {
    for pair in flatten([
      for dns_zone_key in local.dns_zones : [
        for spoke_key, spoke_config in var.spoke_vnet_configs : {
          dns_zone_key = dns_zone_key
          spoke_key    = spoke_key
          spoke_config = spoke_config
        }
      ]
    ]) : "${pair.dns_zone_key}-${pair.spoke_key}" => pair
  }

  name                  = "link-${each.value.spoke_key}-${replace(each.value.dns_zone_key, ".", "-")}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_zones[each.value.dns_zone_key].name
  virtual_network_id    = azurerm_virtual_network.spoke[each.value.spoke_key].id
  registration_enabled  = false # ✅ CRITICAL: False for private endpoints
  tags                  = { "Environment" = "POC" }

  depends_on = [
    azurerm_private_dns_zone.private_dns_zones,
    azurerm_virtual_network.spoke
  ]
}

# Private Endpoints
resource "azurerm_private_endpoint" "pe" {
  for_each = var.private_endpoint_configs

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.value.subnet_id

  private_service_connection {
    name                           = each.value.private_service_connection.name
    is_manual_connection           = each.value.private_service_connection.is_manual_connection
    private_connection_resource_id = each.value.private_service_connection.private_connection_resource_id
    subresource_names              = each.value.private_service_connection.subresource_names
  }

  dynamic "private_dns_zone_group" {
    for_each = each.value.private_dns_zone_ids != null ? [1] : []
    content {
      name                 = lookup(each.value, "private_dns_zone_group_name", "default")
      private_dns_zone_ids = each.value.private_dns_zone_ids
    }
  }
  tags = lookup(each.value, "tags", null)
}

# Azure Bastion Host
resource "azurerm_public_ip" "bastion_pip" {
  count = var.bastion_host_config != null ? 1 : 0

  name                = "${var.bastion_host_config.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = var.bastion_host_config.public_ip_sku
  tags                = lookup(var.bastion_host_config, "tags", null)
}

resource "azurerm_bastion_host" "bastion" {
  count = var.bastion_host_config != null ? 1 : 0

  name                = var.bastion_host_config.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = lookup(var.bastion_host_config, "tags", null)

  ip_configuration {
    name = "${var.bastion_host_config.name}-ipconfig"
    #   CLEANER: Use subnet key from config
    subnet_id            = azurerm_subnet.subnet[var.bastion_host_config.subnet_key].id
    public_ip_address_id = azurerm_public_ip.bastion_pip[0].id
  }
}

# ✅ VNet Peerings for Hub-Spoke Connectivity (OnPrem Simulation via Peering)
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spoke_vnet_configs

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  allow_virtual_network_access = true   # ✅ ADD THIS
  allow_gateway_transit        = false
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spoke_vnet_configs

  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true   # ✅ ADD THIS
  allow_gateway_transit        = false
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

# ✅ CENTRALIZED: NAT Gateway in Hub for All Internet Exit
resource "azurerm_public_ip" "hub_nat_gateway_pip" {
  name                = "pip-natgw-hub-POCpub-1"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"] # ✅ FIX: Public IP can only have one zone to match NAT Gateway

  tags = {
    Environment = "POC"
    Purpose     = "Hub_NAT_Gateway_Internet_Exit"
  }
}

resource "azurerm_nat_gateway" "hub_nat_gateway" {
  name                    = "natgw-hub-POCpub-1"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"] # ✅ FIX: NAT Gateway can only have one zone

  tags = {
    Environment = "POC"
    Purpose     = "Hub_Centralized_Internet_Exit"
  }
}

resource "azurerm_nat_gateway_public_ip_association" "hub_nat_pip" {
  nat_gateway_id       = azurerm_nat_gateway.hub_nat_gateway.id
  public_ip_address_id = azurerm_public_ip.hub_nat_gateway_pip.id
}

# ✅ CRITICAL: Remove references to snet_hub_nat if not defined
resource "azurerm_subnet_nat_gateway_association" "hub_nat" {
  # ✅ FIX: Only create if subnet exists
  count = contains(keys(var.subnet_configs), "snet_hub_nat") ? 1 : 0

  subnet_id      = azurerm_subnet.subnet["snet_hub_nat"].id
  nat_gateway_id = azurerm_nat_gateway.hub_nat_gateway.id

  lifecycle {
    ignore_changes = [
      subnet_id,
      nat_gateway_id
    ]
  }
}

# ✅ DNS Resolver Service in Hub Network
resource "azurerm_private_dns_resolver" "hub_dns_resolver" {
  name                = "dns-resolver-hub-POCpub-1"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_network_id  = azurerm_virtual_network.hub.id

  tags = {
    Environment = "POC"
    Purpose     = "HubDNSResolver_NameResolution"
  }
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "hub_inbound" {
  name                    = "dns-in-hub-POCpub-1"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub_dns_resolver.id
  location                = var.location

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.subnet["snet_hub_dns_inbound"].id
  }

  tags = {
    Environment = "POC"
    Purpose     = "DNS_InboundEndpoint_Hub"
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "hub_outbound" {
  name                    = "dns-out-hub-POCpub-1"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub_dns_resolver.id
  location                = var.location
  subnet_id               = azurerm_subnet.subnet["snet_hub_dns_outbound"].id

  tags = {
    Environment = "POC"
    Purpose     = "DNS_OutboundEndpoint_Hub"
  }
}

# DNS Forwarding Rules for OnPrem Simulation
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "hub_forwarding" {
  name                                       = "dns-fwd-hub-POCpub-1"
  resource_group_name                        = var.resource_group_name
  location                                   = var.location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.hub_outbound.id]

  tags = {
    Environment = "POC"
    Purpose     = "DNS_ForwardingRules_OnPremSim"
  }
}

resource "azurerm_private_dns_resolver_forwarding_rule" "onprem_local" {
  name                      = "rule-onprem-local"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub_forwarding.id
  domain_name               = "onprem.local."
  enabled                   = true

  target_dns_servers {
    ip_address = "192.168.1.10"
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_forwarding_rule" "corp_contoso" {
  name                      = "rule-corp-contoso"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub_forwarding.id
  domain_name               = "corp.contoso.com."
  enabled                   = true

  target_dns_servers {
    ip_address = "192.168.1.11"
    port       = 53
  }
}

# Link DNS Forwarding Ruleset to VNets
resource "azurerm_private_dns_resolver_virtual_network_link" "hub_link" {
  name                      = "link-hub-dns"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub_forwarding.id
  virtual_network_id        = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_resolver_virtual_network_link" "spoke_links" {
  for_each                  = var.spoke_vnet_configs
  name                      = "link-${each.key}-dns"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub_forwarding.id
  virtual_network_id        = azurerm_virtual_network.spoke[each.key].id
}


