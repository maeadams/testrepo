output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.name
}

output "log_analytics_workspace_key" {
  description = "Primary shared key of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.primary_shared_key
  sensitive   = true
}

# ✅ ADD: Action Group IDs output
output "action_group_ids" {
  description = "Map of Action Group names to their IDs"
  value = {
    for k, v in azurerm_monitor_action_group.action_group : k => v.id
  }
}

# ✅ ADD: Data Collection Rule IDs output (for VM monitoring)
output "data_collection_rule_ids" {
  description = "Map of Data Collection Rule names to their IDs"
  value       = {} # Will be populated when DCRs are enabled
}
