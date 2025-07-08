# Terraform Azure Storage Module

## Purpose

This module is responsible for deploying and managing various Azure storage solutions and backup capabilities. It handles:
-   Azure Storage Accounts with configurable tiers, replication, kind, and access tiers.
-   Blob versioning and soft delete policies for storage accounts.
-   (Optional) Customer-Managed Keys (CMK) for storage account encryption, integrating with Azure Key Vault.
-   Network rules for storage accounts (IP rules, VNet subnet access).
-   Azure Blob Containers within storage accounts.
-   Azure Managed Disks with different storage types, create options, and sizes.
-   Azure Recovery Services Vault for backup and site recovery.
-   VM Backup Policies defining backup frequency and retention.
-   Configuration for backing up specific Virtual Machines.
-   (Placeholder) Site Recovery configurations (fabric, protection container, replication policy).

## Inputs

| Name                               | Description                                                                                                | Type        | Default | Required |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------- | ------- | :------: |
| `resource_group_name`              | The name of the resource group where storage resources will be deployed.                                     | `string`    |         |   yes    |
| `location`                         | The Azure region where storage resources will be deployed.                                                   | `string`    |         |   yes    |
| `key_vault_id`                     | The ID of the Key Vault for Customer-Managed Key (CMK) encryption of storage accounts.                     | `string`    |         |   yes    |
| `storage_accounts`                 | Map of storage account configurations.                                                                     | `map(object)` | `{}`    |    no    |
| `storage_containers`               | Map of blob container configurations. `storage_account_name` must match a key in `var.storage_accounts`.   | `map(object)` | `{}`    |    no    |
| `managed_disks`                    | Map of managed disk configurations.                                                                        | `map(object)` | `{}`    |    no    |
| `recovery_services_vault_config`   | Configuration for the Recovery Services Vault.                                                               | `object`    |         |   yes    |
| `backup_policies_vm`               | Map of VM backup policy configurations. `recovery_vault_name` must match `var.recovery_services_vault_config.name`. | `map(object)` | `{}`    |    no    |
| `vms_to_backup`                    | Map of VMs to backup. `recovery_vault_name` and `policy_name` must match existing vault and policy names. | `map(object)` | `{}`    |    no    |
| `site_recovery_config`             | (Optional) Placeholder for Site Recovery configuration.                                                      | `object`    | `null`  |    no    |

Refer to `variables.tf` in this module for detailed type specifications of the object and map variables.

## Outputs

| Name                                     | Description                                                              |
| ---------------------------------------- | ------------------------------------------------------------------------ |
| `storage_account_ids`                    | Map of storage account logical names to their Azure Resource IDs.        |
| `storage_account_primary_blob_endpoints` | Map of storage account logical names to their primary blob endpoint URLs.  |
| `storage_container_ids`                  | Map of storage container logical names to their Azure Resource IDs.      |
| `managed_disk_ids`                       | Map of managed disk logical names to their Azure Resource IDs.           |
| `recovery_services_vault_id`             | The ID of the deployed Recovery Services Vault.                          |
| `backup_policy_vm_ids`                   | Map of VM backup policy logical names to their Azure Resource IDs.       |

## Usage Example (in root module)

```terraform
module "storage" {
  source = "./modules/storage"

  resource_group_name = module.resource_organization.resource_group_names["storage_rg"]
  location            = var.location
  key_vault_id        = module.security.key_vault_id

  storage_accounts = {
    "mystorageacc1" = {
      name                     = "stdiaglogs${random_string.unique.result}" # Ensure unique name
      account_tier             = "Standard"
      account_replication_type = "LRS"
      access_tier              = "Hot"
      versioning_enabled       = true
      blob_soft_delete_retention_days = 7
      customer_managed_key = {
        key_vault_key_id = module.security.key_vault_key_ids["storage_cmk"] # Example key
      }
    }
  }

  storage_containers = {
    "mycontainer" = {
      name                 = "appdata"
      storage_account_name = "mystorageacc1" # Must match a key in storage_accounts
    }
  }
  
  recovery_services_vault_config = {
    name     = "myRecoveryServicesVault"
    sku      = "Standard" # or RS0
  }

  # ... other configurations ...
}
```

## Specific Implementations (as per PRD)
-   Cold storage for long-term data (via `access_tier = "Cool"` or archive tier if supported directly).
-   Standard and Premium managed disks (via `var.managed_disks.storage_account_type`).
-   Storage versioning and encryption with CMK (via `var.storage_accounts` properties).
-   Azure Backup for VMs (via `azurerm_backup_policy_vm` and `azurerm_backup_protected_vm`).
-   Geo-redundant storage (GRS) for resilience (via `var.storage_accounts.account_replication_type`).
-   VM and file restoration (capabilities provided by Azure Backup, demonstrated through Azure portal/CLI).

## Managing Individual Resources (Targeting)

While this module is typically applied as a whole from the root configuration, you can manage individual resources within this module using Terraform's `-target` option. This is generally used for specific troubleshooting or development scenarios.

**Note:** `<module_instance_name>` below refers to the name given to this module instance in your root `main.tf` file (e.g., `module.storage_services`).

**Planning changes for a specific resource (e.g., a Storage Account):**
```bash
terraform plan -target='module.<module_instance_name>.azurerm_storage_account.sa["your_sa_key"]'
```

**Applying changes to a specific resource (e.g., a Recovery Services Vault):**
```bash
terraform apply -target='module.<module_instance_name>.azurerm_recovery_services_vault.rsv'
```

**Destroying a specific resource (e.g., a Managed Disk):**
```bash
terraform destroy -target='module.<module_instance_name>.azurerm_managed_disk.disk["your_disk_key"]'
```

Replace `"your_sa_key"` or `"your_disk_key"` with the actual key used in your `for_each` loop for that resource type within this module (as defined in your root module's variables). For singleton resources like the vault, no key is needed.

**Caution:** Using `-target` can lead to configuration drift if not managed carefully. It's generally recommended to apply or destroy the entire module configuration to maintain consistency.
