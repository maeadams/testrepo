# Terraform Azure Resource Organization Module

## Purpose

This module is responsible for establishing the foundational resource hierarchy in Azure, including:
-   Management Groups
-   Custom Azure Policy Definitions
-   Policy Assignments
-   Resource Groups that will contain resources deployed by other modules.

It helps in organizing resources logically, applying governance through policies, and preparing the environment for subsequent module deployments.

## Inputs

| Name                      | Description                                                                 | Type                                                                                                                               | Default | Required |
| ------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------- | :------: |
| `management_group_config` | Configuration for Management Groups. Defines hierarchy, names, and display names. | `map(object({ name = string, display_name = string, parent_id = optional(string) }))`                                            | `{}`    |    no    |
| `policy_definitions`      | Custom Azure Policy definitions to be created.                              | `map(object({ policy_type = string, mode = string, display_name = string, description = string, policy_rule = any, metadata = optional(any) }))` | `{}`    |    no    |
| `policy_assignments`      | Policy assignment configurations. Links policy definitions to specific scopes.  | `map(object({ scope = string, policy_definition_name = string, description = string, location = string, parameters = optional(any) }))` | `{}`    |    no    |
| `resource_groups`         | Configuration for Resource Groups to be created by this module.             | `map(object({ name = string, location = string, tags = optional(map(string)) }))`                                                   | `{}`    |    no    |

**Note on `policy_assignments.scope`**: For `azurerm_subscription_policy_assignment` (which this module currently uses), the `scope` should be the Subscription ID.
**Note on `policy_assignments.location`**: This is required for subscription-level policy assignments.

## Outputs

| Name                    | Description                                                 |
| ----------------------- | ----------------------------------------------------------- |
| `resource_group_ids`    | Map of resource group logical names (keys from `var.resource_groups`) to their Azure Resource IDs. |
| `resource_group_names`  | Map of resource group logical names to their actual Azure names. |
| `management_group_ids`  | Map of management group logical names (keys from `var.management_group_config`) to their Azure Resource IDs. |
| `policy_definition_ids` | Map of policy definition logical names (keys from `var.policy_definitions`) to their Azure Resource IDs. |

## Usage Example (in root module)

```terraform
module "resource_organization" {
  source = "./modules/resource-organization"

  management_group_config = {
    "mg-landing-zones" = {
      name         = "mg-lz"
      display_name = "Landing Zones MG"
    }
  }
  resource_groups = {
    "network_rg" = {
      name     = "my-corp-network-rg"
      location = "WestEurope"
      tags = {
        environment = "production"
        costcenter  = "IT"
      }
    }
    # ... other resource groups
  }
  # ... other variable inputs
}
```

## Specific Implementations (as per PRD)

This module is intended to support:
-   Tag inheritance policy (Step #29) - via `azurerm_policy_definition` and `azurerm_subscription_policy_assignment`.
-   VM size restriction policy to deny E-series VMs (Step #30) - via `azurerm_policy_definition` and `azurerm_subscription_policy_assignment`.
-   Resource tagging strategy for cost allocation - by creating resource groups with appropriate tags and enabling policies for tag enforcement.

## Managing Individual Resources (Targeting)

While this module is typically applied as a whole from the root configuration, you can manage individual resources within this module using Terraform's `-target` option. This is generally used for specific troubleshooting or development scenarios.

**Note:** `<module_instance_name>` below refers to the name given to this module instance in your root `main.tf` file (e.g., `module.my_org_setup`).

**Planning changes for a specific resource:**
```bash
terraform plan -target='module.<module_instance_name>.azurerm_resource_group.rg["your_rg_key"]'
```

**Applying changes to a specific resource:**
```bash
terraform apply -target='module.<module_instance_name>.azurerm_management_group.mg["your_mg_key"]'
```

**Destroying a specific resource:**
```bash
terraform destroy -target='module.<module_instance_name>.azurerm_policy_definition.policy["your_policy_def_key"]'
```

Replace `"your_rg_key"`, `"your_mg_key"`, or `"your_policy_def_key"` with the actual key used in your `for_each` loop for that resource type within this module (as defined in your root module's variables).

**Caution:** Using `-target` can lead to configuration drift if not managed carefully. It's generally recommended to apply or destroy the entire module configuration to maintain consistency.
