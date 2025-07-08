variable "subscription_id" {
  description = "The ID of the subscription for which the budget will be created."
  type        = string
}

variable "subscription_budget" {
  description = "Subscription budget settings."
  type = object({
    name        = string
    amount      = number
    time_period = string # "Monthly", "Quarterly", "Annually"
    start_date  = string # YYYY-MM-DD
    end_date    = string # YYYY-MM-DD
    notifications = list(object({
      enabled        = bool
      operator       = string # "EqualTo", "GreaterThan", "GreaterThanOrEqualTo"
      threshold      = number # Percentage (e.g., 80 for 80%)
      contact_emails = list(string)
      contact_groups = optional(list(string))     # Action Group resource IDs
      contact_roles  = optional(list(string))     # e.g., "Owner", "Contributor", "Reader"
      threshold_type = optional(string, "Actual") # "Actual" or "Forecasted"
    }))
    filter = optional(object({
      dimensions = optional(list(object({
        name     = string
        operator = string # "In"
        values   = list(string)
      })))
      tags = optional(list(object({
        name     = string
        operator = string # "In"
        values   = list(string)
      })))
    }))
  })
  default = null # Optional, only create if provided
}

variable "resource_group_budgets" {
  description = "Resource group budget settings."
  type = map(object({
    name                = string
    resource_group_name = string # Name of the resource group
    amount              = number
    time_period         = string
    start_date          = string
    end_date            = string
    notifications = list(object({
      enabled        = bool
      operator       = string
      threshold      = number
      contact_emails = list(string)
      contact_groups = optional(list(string))
      contact_roles  = optional(list(string))
      threshold_type = optional(string, "Actual")
    }))
    filter = optional(object({
      dimensions = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })))
      tags = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })))
    }))
  }))
  default = {}
}

# Note: Cost analysis views are typically configured in the Azure portal or via API,
# not directly as a distinct Terraform resource. Budgets can use filters based on dimensions/tags.
# The 'tag_policy' is handled by the 'resource-organization' module.
