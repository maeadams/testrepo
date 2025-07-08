output "frontdoor_id" {
  description = "The ID of the Front Door."
  value       = length(azurerm_cdn_frontdoor_profile.frontdoor) > 0 ? azurerm_cdn_frontdoor_profile.frontdoor[0].id : null
}

output "frontdoor_endpoint_host_names" {
  description = "The host names of Front Door endpoints."
  value = length(azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint) > 0 ? {
    (azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint[0].name) = azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint[0].host_name
  } : {}
}

output "frontdoor_waf_policy_id" {
  description = "The ID of the Front Door WAF Policy."
  value       = length(azurerm_cdn_frontdoor_firewall_policy.frontdoor_waf) > 0 ? azurerm_cdn_frontdoor_firewall_policy.frontdoor_waf[0].id : null
}

output "redis_cache_ids" {
  description = "Map of Redis Cache names to their IDs."
  value       = { for k, v in azurerm_redis_cache.redis : k => v.id }
}

output "redis_cache_hostnames" {
  description = "Map of Redis Cache names to their hostnames."
  value       = { for k, v in azurerm_redis_cache.redis : k => v.hostname }
}

output "redis_cache_primary_access_keys" {
  description = "Map of Redis Cache names to their primary access keys."
  value       = { for k, v in azurerm_redis_cache.redis : k => v.primary_access_key }
  sensitive   = true
}

output "redis_private_endpoint_ids" {
  description = "Map of Redis Private Endpoint names to their IDs."
  value       = { for k, v in azurerm_private_endpoint.redis_pe : k => v.id }
}
