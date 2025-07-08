#   ADD: Azure Front Door Profile and Endpoint
resource "azurerm_cdn_frontdoor_profile" "frontdoor" {
  count = var.frontdoor_config != null ? 1 : 0

  name                = var.frontdoor_config.name
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = lookup(var.frontdoor_config, "tags", null)
}

resource "azurerm_cdn_frontdoor_endpoint" "frontdoor_endpoint" {
  count = var.frontdoor_config != null ? 1 : 0

  name                     = "endpoint-${var.frontdoor_config.name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor[0].id
  enabled                  = true
  tags                     = lookup(var.frontdoor_config, "tags", null)
}

#   ADD: Front Door Origin Groups and Origins
resource "azurerm_cdn_frontdoor_origin_group" "frontdoor_origin_group" {
  count = var.frontdoor_config != null ? length(var.frontdoor_config.backend_pools) : 0

  name                     = var.frontdoor_config.backend_pools[count.index].name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor[0].id
  session_affinity_enabled = false

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    interval_in_seconds = 240
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

#   FIXED: Front Door Origin
resource "azurerm_cdn_frontdoor_origin" "frontdoor_origins" {
  count = var.frontdoor_config != null ? length(flatten([
    for pool in var.frontdoor_config.backend_pools : pool.backends
  ])) : 0

  name                          = "origin-${count.index}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group[0].id
  enabled                       = true

  #   ADD: Required argument
  certificate_name_check_enabled = true

  host_name          = var.frontdoor_config.backend_pools[0].backends[count.index].address
  http_port          = var.frontdoor_config.backend_pools[0].backends[count.index].http_port
  https_port         = var.frontdoor_config.backend_pools[0].backends[count.index].https_port
  origin_host_header = var.frontdoor_config.backend_pools[0].backends[count.index].host_header
  priority           = var.frontdoor_config.backend_pools[0].backends[count.index].priority
  weight             = var.frontdoor_config.backend_pools[0].backends[count.index].weight

  # ❌ REMOVE: This certificate block is not supported
  # certificate {
  #   certificate_type = "ManagedCertificate"
  # }
}

#   ADD: Front Door WAF Policy
resource "azurerm_cdn_frontdoor_firewall_policy" "frontdoor_waf" {
  count = var.frontdoor_waf_policy_config != null ? 1 : 0

  name                = var.frontdoor_waf_policy_config.name
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  enabled             = var.frontdoor_waf_policy_config.enabled
  mode                = var.frontdoor_waf_policy_config.mode
  tags                = lookup(var.frontdoor_waf_policy_config, "tags", null)

  dynamic "managed_rule" {
    for_each = lookup(var.frontdoor_waf_policy_config, "managed_rules", [])
    content {
      type    = managed_rule.value.type
      version = managed_rule.value.version
      action  = "Block"
    }
  }
}

#   ADD: Redis Cache resource (was missing)
resource "azurerm_redis_cache" "redis" {
  for_each = var.redis_cache_config

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = each.value.capacity
  family              = each.value.family
  sku_name            = each.value.sku_name
  minimum_tls_version = lookup(each.value, "minimum_tls_version", "1.2")

  # Conditional subnet assignment for Premium SKU
  subnet_id = each.value.sku_name == "Premium" ? lookup(each.value, "subnet_id", null) : null

  # Redis configuration
  dynamic "redis_configuration" {
    for_each = lookup(each.value, "redis_configuration", null) != null ? [each.value.redis_configuration] : []
    content {
      maxmemory_reserved              = lookup(redis_configuration.value, "maxmemory_reserved", null)
      maxmemory_delta                 = lookup(redis_configuration.value, "maxmemory_delta", null)
      maxmemory_policy                = lookup(redis_configuration.value, "maxmemory_policy", "volatile-lru")
      maxfragmentationmemory_reserved = lookup(redis_configuration.value, "maxfragmentationmemory_reserved", null)
      rdb_backup_enabled              = lookup(redis_configuration.value, "rdb_backup_enabled", false)
      rdb_backup_frequency            = lookup(redis_configuration.value, "rdb_backup_frequency", null)
      rdb_backup_max_snapshot_count   = lookup(redis_configuration.value, "rdb_backup_max_snapshot_count", null)
      rdb_storage_connection_string   = lookup(redis_configuration.value, "rdb_storage_connection_string", null)
    }
  }

  tags = lookup(each.value, "tags", null)

  lifecycle {
    ignore_changes = [redis_configuration]
  }
}

#   ADD: Redis Firewall Rules
resource "azurerm_redis_firewall_rule" "redis_fw_rule" {
  for_each = var.redis_firewall_rules

  name                = each.value.name
  redis_cache_name    = azurerm_redis_cache.redis[each.value.redis_cache_name].name
  resource_group_name = var.resource_group_name
  start_ip            = each.value.start_ip
  end_ip              = each.value.end_ip

  depends_on = [azurerm_redis_cache.redis]
}

#   ADD: Redis Private Endpoint
resource "azurerm_private_endpoint" "redis_pe" {
  for_each = var.redis_private_endpoint_config

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.value.subnet_id

  private_service_connection {
    name = "psc-${each.value.name}"
    #   FIXED: Use the correct redis cache key reference
    private_connection_resource_id = azurerm_redis_cache.redis[each.value.redis_cache_name].id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.redis_dns_zone[each.key].id]
  }

  tags       = { "Environment" = "POC", "Purpose" = "RedisPrivateAccess" }
  depends_on = [azurerm_redis_cache.redis]
}

#   ADD: Data source for Redis Private DNS Zone
data "azurerm_private_dns_zone" "redis_dns_zone" {
  for_each = var.redis_private_endpoint_config

  name                = each.value.private_dns_zone_name
  resource_group_name = var.resource_group_name
}

#   ADD: Private DNS A Record for Redis
resource "azurerm_private_dns_a_record" "redis_dns" {
  for_each = var.redis_private_endpoint_config

  name                = azurerm_redis_cache.redis[each.value.redis_cache_name].name
  zone_name           = each.value.private_dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.redis_pe[each.key].private_service_connection[0].private_ip_address]

  depends_on = [azurerm_private_endpoint.redis_pe]
}
