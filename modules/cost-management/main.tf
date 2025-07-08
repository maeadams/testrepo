# Subscription Budget
resource "azurerm_consumption_budget_subscription" "subscription_budget" {
  count = var.subscription_budget != null ? 1 : 0

  name            = var.subscription_budget.name
  subscription_id = startswith(var.subscription_id, "/subscriptions/") ? var.subscription_id : "/subscriptions/${var.subscription_id}"
  amount          = var.subscription_budget.amount
  time_period {
    start_date = var.subscription_budget.start_date
    end_date   = var.subscription_budget.end_date
  }
  time_grain = var.subscription_budget.time_period

  dynamic "notification" {
    for_each = var.subscription_budget.notifications
    content {
      enabled        = notification.value.enabled
      operator       = notification.value.operator
      threshold      = notification.value.threshold
      contact_emails = notification.value.contact_emails
      contact_groups = lookup(notification.value, "contact_groups", null)
      contact_roles  = lookup(notification.value, "contact_roles", null)
      threshold_type = lookup(notification.value, "threshold_type", "Actual")
    }
  }

  dynamic "filter" {
    for_each = var.subscription_budget.filter != null ? [var.subscription_budget.filter] : []
    content {
      dynamic "dimension" {
        for_each = lookup(filter.value, "dimensions", [])
        content {
          name     = dimension.value.name
          operator = dimension.value.operator
          values   = dimension.value.values
        }
      }
      # ✅ FIXED: Handle null tags properly
      dynamic "tag" {
        for_each = lookup(filter.value, "tags", null) != null ? lookup(filter.value, "tags", []) : []
        content {
          name     = tag.value.name
          operator = tag.value.operator
          values   = tag.value.values
        }
      }
    }
  }
}

# Resource Group Budgets
resource "azurerm_consumption_budget_resource_group" "rg_budgets" {
  for_each = var.resource_group_budgets

  name              = each.value.name
  resource_group_id = "/subscriptions/${var.subscription_id}/resourceGroups/${each.value.resource_group_name}"
  amount            = each.value.amount
  time_period {
    start_date = each.value.start_date
    end_date   = each.value.end_date
  }
  time_grain = each.value.time_period

  dynamic "notification" {
    for_each = each.value.notifications
    content {
      enabled        = notification.value.enabled
      operator       = notification.value.operator
      threshold      = notification.value.threshold
      contact_emails = notification.value.contact_emails
      contact_groups = lookup(notification.value, "contact_groups", null)
      contact_roles  = lookup(notification.value, "contact_roles", null)
      threshold_type = lookup(notification.value, "threshold_type", "Actual")
    }
  }

  dynamic "filter" {
    for_each = each.value.filter != null ? [each.value.filter] : []
    content {
      dynamic "dimension" {
        for_each = lookup(filter.value, "dimensions", [])
        content {
          name     = dimension.value.name
          operator = dimension.value.operator
          values   = dimension.value.values
        }
      }
      # ✅ FIXED: Handle null tags properly  
      dynamic "tag" {
        for_each = lookup(filter.value, "tags", null) != null ? lookup(filter.value, "tags", []) : []
        content {
          name     = tag.value.name
          operator = tag.value.operator
          values   = tag.value.values
        }
      }
    }
  }
}
