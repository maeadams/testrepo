output "resource_group_ids" {
  description = "Map of resource group keys to their IDs"
  value       = { for rg_key, rg in azurerm_resource_group.rg : rg_key => rg.id }
}

output "resource_group_names" {
  description = "Map of resource group keys to their names"
  value       = { for rg_key, rg in azurerm_resource_group.rg : rg_key => rg.name }
}

output "management_group_ids" {
  description = "Map of management group display names to their IDs"
  value       = { for mg_key, mg in azurerm_management_group.mg : mg_key => mg.id }
}

output "policy_definition_ids" {
  description = "Map of policy definition names to their IDs"
  value       = { for pd_key, pd in azurerm_policy_definition.policy : pd_key => pd.id }
}
