output "subscription_budget_id" {
  description = "ID of the subscription budget"
  value       = var.subscription_budget != null ? azurerm_consumption_budget_subscription.subscription_budget[0].id : null
}

output "resource_group_budget_ids" {
  description = "Map of resource group budget names to their IDs"
  value = {
    for k, v in azurerm_consumption_budget_resource_group.rg_budgets : k => v.id
  }
}
