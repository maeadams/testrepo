variable "resource_group_name" {
  description = "The name of the resource group where security resources will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region where security resources will be deployed."
  type        = string
}

variable "random_suffix" {
  description = "Random suffix for unique naming"
  type        = string
}

variable "disk_encryption_set_config" {
  description = "Disk Encryption Set configuration"
  type = object({
    name_prefix = string
    tags        = optional(map(string))
  })
  default = null
}

variable "subnet_ids" {
  description = "Map of subnet names to their IDs from the network module."
  type        = map(string)
}

variable "firewall_config" {
  description = "Azure Firewall configuration"
  type = object({
    name                    = string
    sku_name                = string
    sku_tier                = string
    public_ip_count         = number
    threat_intel_mode       = string
    firewall_subnet_key_ref = string
    tags                    = optional(map(string))
  })
  default = null
}

variable "firewall_policy_rules" {
  description = "Firewall policy rules configuration"
  type = list(object({
    name     = string
    priority = number
    action   = string
    rules = list(object({
      name = string
      protocols = list(object({
        type = string
        port = number
      }))
      source_addresses      = list(string)
      destination_fqdns     = optional(list(string))
      destination_addresses = optional(list(string))
    }))
  }))
  default = []
}

variable "firewall_network_policy_rules" {
  description = "Firewall network policy rules configuration for TCP/UDP traffic"
  type = list(object({
    name     = string
    priority = number
    action   = string
    rules = list(object({
      name                  = string
      source_addresses      = list(string)
      destination_addresses = list(string)
      destination_ports     = list(string)
      protocols             = list(string)
    }))
  }))
  default = []
}

variable "key_vault_config" {
  description = "Key Vault configuration"
  type = object({
    name                            = string
    sku_name                        = string
    enabled_for_disk_encryption     = bool
    enabled_for_template_deployment = bool
    enable_rbac_authorization       = bool
    soft_delete_retention_days      = number
    purge_protection_enabled        = bool
    access_policies = list(object({
      tenant_id               = string
      object_id               = string
      key_permissions         = list(string)
      secret_permissions      = list(string)
      certificate_permissions = list(string)
    }))
    tags = optional(map(string))
  })
}

variable "encryption_keys" {
  description = "Encryption keys configuration"
  type = map(object({
    name     = string
    key_type = string
    key_size = number
    key_opts = list(string)
    tags     = optional(map(string))
  }))
  default = {}
}

variable "key_vault_secrets" {
  description = "Key Vault secrets configuration"
  type = map(object({
    name  = string
    value = string
    tags  = optional(map(string))
  }))
  default = {}
}

variable "app_gateway_config" {
  description = "Application Gateway configuration"
  type        = any
  default     = null
}

variable "waf_policy_config" {
  description = "WAF Policy configuration"
  type        = any
  default     = null
}

variable "network_resource_group_name" {
  description = "Network resource group name for Application Gateway"
  type        = string
}

variable "compute_module_dependencies" {
  description = "List of compute module dependencies to ensure proper DES destroy order"
  type        = list(string)
  default     = []
}


