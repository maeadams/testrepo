# Terraform Azure Network Module

## Purpose

This module is responsible for deploying the core networking infrastructure for the Azure landing zone. This includes:
-   Hub and Spoke Virtual Networks (VNets).
-   Subnets with delegations and network policy configurations.
-   Network Security Groups (NSGs) with associated rules.
-   Route Tables with custom routes.
-   VNet peerings (implicitly managed by VNet resource for hub/spoke).
-   Network Watcher and VNet Flow Logs.
-   (Optional) Event Hub, Event Grid Topic, and Subscription for flow log integration or general storage events.
-   (Optional) VPN Gateway and connections.
-   (Optional) Private Endpoints and associated Private DNS Zones.
-   (Optional) Azure Bastion Host for secure VM access.

## Inputs

| Name                                 | Description                                                                                                | Type        | Default | Required |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------- | ----------- | ------- | :------: |
| `resource_group_name`                | The name of the resource group where primary network resources will be deployed.                             | `string`    |         |   yes    |
| `location`                           | The Azure region where primary network resources will be deployed.                                           | `string`    |         |   yes    |
| `eventgrid_source_arm_resource_id`   | (Optional) The ARM resource ID for the Event Grid System Topic source (e.g., Storage Account ID).            | `string`    | `null`  |    no    |
| `hub_vnet_config`                    | Configuration for the Hub Virtual Network.                                                                 | `object`    |         |   yes    |
| `spoke_vnet_configs`                 | Configuration for Spoke Virtual Networks.                                                                  | `map(object)` | `{}`    |    no    |
| `subnet_configs`                     | Configuration for Subnets. `virtual_network_name` should match a key from `hub_vnet_config` or `spoke_vnet_configs`. | `map(object)` | `{}`    |    no    |
| `nsg_rules`                          | Network security rules definitions, keyed by NSG name. Each value is a list of rule objects.               | `map(list(object))` | `{}`    |    no    |
| `route_tables`                       | Custom route configurations, keyed by Route Table name.                                                      | `map(object)` | `{}`    |    no    |
| `flow_log_config`                    | (Optional) Flow log settings. If provided, `nsg_name` must match a key in `nsg_rules`.                     | `object`    | `null`  |    no    |
| `vpn_gateway_config`                 | (Optional) VPN Gateway settings.                                                                           | `object`    | `null`  |    no    |
| `private_endpoint_configs`           | (Optional) Private endpoint configurations.                                                                | `map(object)` | `{}`    |    no    |
| `bastion_host_config`                | (Optional) Azure Bastion Host configuration. Requires a subnet named `AzureBastionSubnet` in `subnet_configs`. | `object`    | `null`  |    no    |

Refer to `variables.tf` in this module for detailed type specifications of the object and map variables.

## Outputs

| Name                         | Description                                                                 |
| ---------------------------- | --------------------------------------------------------------------------- |
| `vnet_ids`                   | Map of Virtual Network names (hub and spokes) to their IDs.                 |
| `subnet_ids`                 | Map of Subnet names (from `var.subnet_configs` keys) to their IDs.          |
| `network_security_group_ids` | Map of Network Security Group names (from `var.nsg_rules` keys) to their IDs. |
| `route_table_ids`            | Map of Route Table names (from `var.route_tables` keys) to their IDs.       |
| `vpn_gateway_id`             | The ID of the VPN Gateway, if created.                                      |
| `bastion_host_id`            | The ID of the Bastion Host, if created.                                     |
# Add other outputs like private endpoint IDs, DNS zone IDs if they are consistently created.

## Usage Example (in root module)

```terraform
module "network" {
  source = "./modules/network"

  resource_group_name = module.resource_organization.resource_group_names["network_rg_key"] # Key from resource_groups in resource_organization
  location            = var.location

  hub_vnet_config = {
    name          = "my-hub-vnet"
    address_space = ["10.0.0.0/16"]
    tags          = { environment = "hub" }
  }

  spoke_vnet_configs = {
    "spoke1" = {
      name          = "my-spoke1-vnet"
      address_space = ["10.1.0.0/16"]
      tags          = { environment = "spoke1" }
    }
  }

  subnet_configs = {
    "HubGatewaySubnet" = { # Must be named GatewaySubnet for VPN Gateway
      name                 = "GatewaySubnet"
      address_prefixes     = ["10.0.0.0/27"]
      virtual_network_name = "my-hub-vnet" # Matches hub_vnet_config.name
    }
    "AzureFirewallSubnet" = { # Must be named AzureFirewallSubnet for Azure Firewall
      name                 = "AzureFirewallSubnet"
      address_prefixes     = ["10.0.1.0/24"]
      virtual_network_name = "my-hub-vnet"
    }
    "AzureBastionSubnet" = { # Must be named AzureBastionSubnet for Bastion
      name                 = "AzureBastionSubnet"
      address_prefixes     = ["10.0.2.0/27"]
      virtual_network_name = "my-hub-vnet"
    }
    "Spoke1DefaultSubnet" = {
      name                 = "default"
      address_prefixes     = ["10.1.0.0/24"]
      virtual_network_name = "my-spoke1-vnet" # Matches a key in spoke_vnet_configs
    }
  }

  # ... other configurations ...
}
```

## Specific Implementations (as per PRD)
- Hub and spoke network topology.
- Internet, Frontend, and Backend subnets (defined via `var.subnet_configs`).
- NSGs for subnet security.
- Routing tables to control subnet traffic.
- VNet flow logs with Event Hub integration (optional, via `var.flow_log_config`).
- Bastion host for secure VM access (optional, via `var.bastion_host_config`).
- VNet-to-VNet VPN connectivity (optional, via `var.vpn_gateway_config`).

## Managing Individual Resources (Targeting)

While this module is typically applied as a whole from the root configuration, you can manage individual resources within this module using Terraform's `-target` option. This is generally used for specific troubleshooting or development scenarios.

**Note:** `<module_instance_name>` below refers to the name given to this module instance in your root `main.tf` file (e.g., `module.networking`).

**Planning changes for a specific resource (e.g., a VNet):**
```bash
terraform plan -target='module.<module_instance_name>.azurerm_virtual_network.hub'
terraform plan -target='module.<module_instance_name>.azurerm_virtual_network.spoke["your_spoke_key"]'
```

**Applying changes to a specific resource (e.g., an NSG):**
```bash
terraform apply -target='module.<module_instance_name>.azurerm_network_security_group.nsg["your_nsg_key"]'
```

**Destroying a specific resource (e.g., a subnet):**
```bash
terraform destroy -target='module.<module_instance_name>.azurerm_subnet.subnet["your_subnet_key"]'
```

Replace `"your_spoke_key"`, `"your_nsg_key"`, or `"your_subnet_key"` with the actual key used in your `for_each` loop for that resource type within this module (as defined in your root module's variables).

**Caution:** Using `-target` can lead to configuration drift if not managed carefully. It's generally recommended to apply or destroy the entire module configuration to maintain consistency.
