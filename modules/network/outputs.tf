output "hub_vnet_id" {
  description = "ID of the Hub Virtual Network"
  value       = azurerm_virtual_network.hub.id
}

output "spoke_vnet_ids" {
  description = "Map of spoke VNet names to their IDs"
  value = {
    for k, v in azurerm_virtual_network.spoke : k => v.id
  }
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = {
    for k, v in azurerm_subnet.subnet : k => v.id
  }
}

# ✅ ADD: Specific firewall subnet output
output "firewall_subnet_id" {
  description = "ID of the Azure Firewall subnet"
  value       = lookup(azurerm_subnet.subnet, "snet_hub_firewall", null) != null ? azurerm_subnet.subnet["snet_hub_firewall"].id : null
}

output "network_security_group_ids" {
  description = "Map of Network Security Group names to their IDs."
  value       = { for k, v in azurerm_network_security_group.nsg : k => v.id }
}

output "network_security_group_names" {
  description = "Map of Network Security Group logical keys to their actual names."
  value       = { for k, v in azurerm_network_security_group.nsg : k => v.name }
}



output "route_table_names" {
  description = "Map of Route Table logical keys to their actual names."
  value       = { for k, v in azurerm_route_table.route_table : k => v.name }
}



output "expressroute_gateway_id" {
  description = "ID of the ExpressRoute Gateway"
  value       = null # Will be implemented when ER gateway is added
}

output "bastion_host_fqdn" {
  description = "FQDN of the Bastion Host"
  value       = var.bastion_host_config != null ? azurerm_bastion_host.bastion[0].dns_name : null
}

output "private_dns_zone_ids" {
  description = "IDs of private DNS zones"
  value = {
    for key, zone in azurerm_private_dns_zone.private_dns_zones :
    zone.name => zone.id
  }
}

output "nsg_ids" {
  description = "Map of NSG names to their IDs"
  value = {
    for k, v in azurerm_network_security_group.nsg : k => v.id
  }
}

output "route_table_ids" {
  description = "Map of route table names to their IDs"
  value = {
    for k, v in azurerm_route_table.route_table : k => v.id
  }
}

# ✅ Hub NAT Gateway Outputs
output "nat_gateway_id" {
  description = "ID of the Hub NAT Gateway for centralized internet exit"
  value       = azurerm_nat_gateway.hub_nat_gateway.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the Hub NAT Gateway"
  value       = azurerm_public_ip.hub_nat_gateway_pip.ip_address
}

# ✅ DNS Resolver Outputs
output "dns_resolver_id" {
  description = "ID of the Hub DNS Resolver"
  value       = azurerm_private_dns_resolver.hub_dns_resolver.id
}

output "dns_resolver_inbound_endpoint_ip" {
  description = "IP address of the DNS Resolver inbound endpoint"
  value       = azurerm_private_dns_resolver_inbound_endpoint.hub_inbound.ip_configurations[0].private_ip_address
}

# ✅ VNet Peering Outputs
output "vnet_peering_hub_to_spoke" {
  description = "Map of hub-to-spoke VNet peering IDs"
  value = {
    for k, v in azurerm_virtual_network_peering.hub_to_spoke : k => v.id
  }
}

output "vnet_peering_spoke_to_hub" {
  description = "Map of spoke-to-hub VNet peering IDs"
  value = {
    for k, v in azurerm_virtual_network_peering.spoke_to_hub : k => v.id
  }
}
