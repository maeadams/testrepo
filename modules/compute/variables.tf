variable "resource_group_name" {
  description = "The name of the resource group where compute resources will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region where compute resources will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet names to their IDs, for network interface association."
  type        = map(string)
}

variable "random_suffix" {
  description = "Random suffix for unique naming"
  type        = string
  default     = ""
}

variable "key_vault_id" {
  description = "Key Vault ID for disk encryption"
  type        = string
  default     = ""
}

variable "disk_encryption_key_url" {
  description = "The URL of the Key Vault Key for disk encryption."
  type        = string
}

variable "disk_encryption_set_id" {
  description = "The ID of the shared Disk Encryption Set from security module."
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace for Azure Monitor Agent."
  type        = string
}

variable "log_analytics_workspace_key" {
  description = "The primary shared key of the Log Analytics workspace."
  type        = string
  sensitive   = true
}

variable "windows_events_dcr_id" {
  description = "ID of the Data Collection Rule for Windows events"
  type        = string
  default     = null
}

variable "windows_vms" {
  description = "Windows VM configurations"
  type = map(object({
    name_prefix    = string           #   FIXED: was "name"
    computer_name  = optional(string) #   ADD: explicit computer name
    size           = string
    admin_username = string
    admin_password = string
    subnet_name    = string
    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    os_disk = object({
      caching              = string
      storage_account_type = string
    })
    data_disks = optional(list(object({
      name                 = string
      lun                  = number
      caching              = string
      storage_account_type = string
      disk_size_gb         = number
      create_option        = string
    })), [])
    enable_azure_monitor_agent = optional(bool, true)
    tags                       = optional(map(string))
  }))
  default = {}
}

variable "linux_vms" {
  description = "Linux VM configurations"
  type = map(object({
    name_prefix    = string #   FIXED: was "name"
    size           = string
    admin_username = string
    admin_ssh_key = object({
      username   = string
      public_key = string
    })
    subnet_name = string
    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    os_disk = object({
      caching              = string
      storage_account_type = string
    })
    data_disks = optional(list(object({
      name                 = string
      lun                  = number
      caching              = string
      storage_account_type = string
      disk_size_gb         = number
      create_option        = string
    })), [])
    enable_azure_monitor_agent = optional(bool, true)
    tags                       = optional(map(string))
  }))
  default = {}
}

variable "vm_extensions" {
  description = "Generic VM extension configurations"
  type = map(object({
    name                 = string
    virtual_machine_name = string # Key of the VM in windows_vms or linux_vms map
    publisher            = string
    type                 = string
    type_handler_version = string
    settings             = optional(string) # JSON string
    protected_settings   = optional(string) # JSON string, sensitive
    tags                 = optional(map(string))
  }))
  default = {}
}

# ✅ REMOVED: disk_encryption_set_config no longer needed in compute module
# DES is now centrally managed in the security module

variable "security_resource_group_name" {
  description = "Resource group name for security resources like DES"
  type        = string
}
