variable "resource_group_name" {
  description = "The name of the resource group where CDN and Caching resources will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region where CDN and Caching resources will be deployed. Note: Front Door is global but requires a location for the resource definition."
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet names to their IDs, for Redis VNet Link if PE is used."
  type        = map(string)
  default     = {}
}

variable "frontdoor_config" {
  description = "Azure Front Door configuration"
  type = object({
    name = string
    routing_rules = list(object({
      name               = string
      accepted_protocols = list(string)
      patterns_to_match  = list(string)
      enabled            = bool
      forwarding_configuration = object({
        backend_pool_name   = string
        forwarding_protocol = string
      })
    }))
    backend_pools = list(object({
      name = string
      backends = list(object({
        host_header = string
        address     = string
        http_port   = number
        https_port  = number
        weight      = number
        priority    = number
      }))
      load_balancing_name = string
      health_probe_name   = string
    }))
    tags = optional(map(string))
  })
  default = null
}

variable "frontdoor_waf_policy_config" {
  description = "Front Door WAF Policy configuration"
  type = object({
    name    = string
    enabled = bool
    mode    = string
    managed_rules = optional(list(object({
      type    = string
      version = string
    })))
    tags = optional(map(string))
  })
  default = null
}

variable "frontdoor_custom_https_config" {
  description = "Front Door custom HTTPS configuration"
  type        = map(any)
  default     = {}
}

variable "redis_cache_config" {
  description = "Azure Redis Cache settings"
  type = map(object({
    name                = string
    capacity            = number
    family              = string # C, P, F
    sku_name            = string # Basic, Standard, Premium
    enable_non_ssl_port = optional(bool, false)
    minimum_tls_version = optional(string, "1.2")
    subnet_id           = optional(string) # For VNet injection (Premium SKU)
    static_ip_address   = optional(string) # For VNet injection
    redis_configuration = optional(object({
      maxmemory_reserved              = optional(string)
      maxmemory_delta                 = optional(string)
      maxfragmentationmemory_reserved = optional(string)
      rdb_backup_enabled              = optional(bool)
      rdb_backup_frequency            = optional(string) # "15min", "30min", "60min", "6h", "12h", "24h"
      rdb_backup_max_snapshot_count   = optional(number)
      rdb_storage_connection_string   = optional(string) # Sensitive
    }))
    patch_schedule = optional(list(object({
      day_of_week        = string
      start_hour_utc     = number
      maintenance_window = optional(string) # PT5H
    })), [])
    tags = optional(map(string))
  }))
  default = {}
}

variable "redis_firewall_rules" {
  description = "Firewall rules for Azure Redis Cache"
  type = map(object({
    redis_cache_name = string
    name             = string
    start_ip         = string
    end_ip           = string
  }))
  default = {}
}

variable "redis_private_endpoint_config" {
  description = "Redis private endpoint configuration"
  type = map(object({
    redis_cache_name      = string
    name                  = string
    subnet_id             = string
    private_dns_zone_name = string
  }))
  default = {}
}

variable "vnet_id" {
  description = "The ID of the VNet for private DNS zone linking."
  type        = string
  default     = ""
}
