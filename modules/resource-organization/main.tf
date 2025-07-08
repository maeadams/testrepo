# ---------------------------------------------------------------------------
# Management Groups
# ---------------------------------------------------------------------------
resource "azurerm_management_group" "mg" {
  for_each = var.management_group_config

  name                       = each.value.name
  display_name               = each.value.display_name
  parent_management_group_id = lookup(each.value, "parent_id", null)
}

# ---------------------------------------------------------------------------
# Policy Definitions
# ---------------------------------------------------------------------------
resource "azurerm_policy_definition" "policy" {
  for_each = var.policy_definitions

  name         = each.key
  policy_type  = each.value.policy_type
  mode         = each.value.mode
  display_name = each.value.display_name
  description  = each.value.description
  # ✅ Apply jsonencode here in the module
  policy_rule = jsonencode(each.value.policy_rule)
  metadata    = lookup(each.value, "metadata", null)
}

# ---------------------------------------------------------------------------
# Policy Assignments
# ---------------------------------------------------------------------------
resource "azurerm_subscription_policy_assignment" "assignment" {
  for_each = var.policy_assignments


  subscription_id = startswith(each.value.scope, "/subscriptions/") ? each.value.scope : "/subscriptions/${each.value.scope}"

  policy_definition_id = azurerm_policy_definition.policy[each.value.policy_definition_name].id




  name        = each.key
  description = each.value.description
  parameters  = lookup(each.value, "parameters", null)
  location    = each.value.location
}

# ---------------------------------------------------------------------------
# Resource Groups
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  for_each = var.resource_groups

  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags
}
