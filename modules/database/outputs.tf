output "sql_mi_id" {
  description = "ID of the SQL Managed Instance"
  value       = azurerm_mssql_managed_instance.sql_mi.id
}

output "sql_mi_fqdn" {
  description = "FQDN of the SQL Managed Instance"
  value       = azurerm_mssql_managed_instance.sql_mi.fqdn
}

# ✅ REMOVED: Private endpoint outputs - no longer applicable with delegation
# output "sql_mi_private_endpoint_ip" {
#   description = "Private IP address of SQL MI private endpoint"
#   value = var.private_endpoint_config != null ? {
#     for k, v in azurerm_private_endpoint.sql_mi_pe : k => v.private_service_connection[0].private_ip_address
#   } : {}
# }

output "sql_mi_private_dns_zone_ids" {
  description = "Map of SQL MI private DNS zone names to their IDs"
  value = {
    for k, v in data.azurerm_private_dns_zone.sql_mi_pdnsz : k => v.id
  }
}

# ✅ REMOVED: Private endpoint specific outputs
# output "sql_managed_instance_private_ip" {
#   description = "Private IP of SQL MI via private endpoint"
#   value       = var.private_endpoint_config != null && length(azurerm_private_endpoint.sql_mi_pe) > 0 ? values(azurerm_private_endpoint.sql_mi_pe)[0].private_service_connection[0].private_ip_address : null
# }

# output "private_endpoint_sql_mi_id" {
#   description = "ID of the SQL MI private endpoint"
#   value       = var.private_endpoint_config != null && length(azurerm_private_endpoint.sql_mi_pe) > 0 ? values(azurerm_private_endpoint.sql_mi_pe)[0].id : null
# }

#   ADD: Direct SQL MI connection info (since no private endpoint)
output "sql_managed_instance_connection_string" {
  description = "Connection string template for SQL Managed Instance."
  value       = "Server=${azurerm_mssql_managed_instance.sql_mi.fqdn};Database=YOUR_DATABASE;Integrated Security=false;User ID=${azurerm_mssql_managed_instance.sql_mi.administrator_login};Password=YOUR_PASSWORD;Connect Timeout=30;Encrypt=true;TrustServerCertificate=false;ApplicationIntent=ReadWrite;MultiSubnetFailover=false"
  sensitive   = false
}

output "sql_managed_instance_admin_login" {
  description = "The administrator login name of the SQL Managed Instance."
  value       = azurerm_mssql_managed_instance.sql_mi.administrator_login
}

# ✅ CRITICAL: Output SQL MI Principal ID for Key Vault access policy
output "sql_mi_principal_id" {
  description = "Principal ID of the SQL Managed Instance managed identity"
  value       = azurerm_mssql_managed_instance.sql_mi.identity[0].principal_id
}
