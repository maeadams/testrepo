variable "management_group_config" {
  description = "Management group hierarchy structure"
  type = map(object({
    name         = string
    display_name = string
    parent_id    = optional(string)
  }))
}

variable "policy_definitions" {
  description = "Custom Azure Policy definitions"
  type = map(object({
    policy_type  = string
    mode         = string
    display_name = string
    description  = string
    policy_rule  = any # ✅ Changed from string to any
    metadata     = optional(any)
  }))
}

variable "policy_assignments" {
  description = "Policy assignment configurations"
  type = map(object({
    scope                  = string # Expected to be a subscription ID for azurerm_subscription_policy_assignment
    policy_definition_name = string
    description            = string
    location               = string # Required for subscription policy assignment
    parameters             = optional(any)
  }))
}

variable "resource_groups" {
  description = "Resource group configurations"
  type = map(object({
    name     = string
    location = string
    tags     = optional(map(string))
  }))
}
