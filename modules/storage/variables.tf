variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID for secrets"
  type        = string
}

variable "storage_accounts" {
  description = "Storage account configurations"
  type = map(object({
    name                              = string
    account_tier                      = string
    account_replication_type          = string
    account_kind                      = string
    access_tier                       = optional(string)
    versioning_enabled                = optional(bool, false)
    blob_soft_delete_retention_days   = optional(number, 7)
    min_tls_version                   = optional(string, "TLS1_2")
    https_traffic_only_enabled        = optional(bool, true)
    infrastructure_encryption_enabled = optional(bool, false)
    allow_shared_key_access           = optional(bool, true)
    tags                              = optional(map(string), {})
  }))
}

variable "storage_containers" {
  description = "Storage container configurations"
  type = map(object({
    name                    = string
    storage_account_key_ref = string
    container_access_type   = string
  }))
  default = {}
}

variable "managed_disks" {
  description = "Managed disk configurations"
  type = map(object({
    name                 = string
    storage_account_type = string
    create_option        = string
    disk_size_gb         = number
    tags                 = optional(map(string), {})
  }))
  default = {}
}

variable "recovery_services_vault_config" {
  description = "Recovery Services Vault configuration"
  type = object({
    name                = string
    sku                 = string
    soft_delete_enabled = bool
    tags                = optional(map(string), {})
  })
  default = null
}

variable "backup_policies_vm" {
  description = "VM backup policies"
  type = map(object({
    name = string
    backup = object({
      frequency = string
      time      = string
    })
    retention_daily = object({
      count = number
    })
    retention_weekly = object({
      count    = number
      weekdays = list(string)
    })
    retention_monthly = object({
      count    = number
      weekdays = list(string)
      weeks    = list(string)
    })
    retention_yearly = object({
      count    = number
      weekdays = list(string)
      weeks    = list(string)
      months   = list(string)
    })
  }))
  default = {}
}

variable "vms_to_backup" {
  description = "VMs to backup configuration"
  type        = map(any)
  default     = {}
}

# Site Recovery variables are complex and depend on specific DR scenarios (Azure to Azure, VMware to Azure, etc.)
# For this PoC, we'll keep it minimal or placeholder.
variable "site_recovery_config" {
  description = "Site recovery configuration"
  type = object({
    fabric_name = string
  })
  default = null
}
