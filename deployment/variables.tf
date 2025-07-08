
# -----------------------------------------------------------------------------
# Resource Organization Module Variables
# -----------------------------------------------------------------------------
variable "management_group_config" {
  description = "Configuration for Management Groups."
  type = map(object({
    name         = string
    display_name = string
    parent_id    = optional(string)
  }))
  default = {}
}


variable "policy_definitions" {
  description = "Custom Azure Policy definitions"
  type = map(object({
    policy_type  = string
    mode         = string
    display_name = string
    description  = string
    policy_rule  = any # ✅ Changed from string to any
    metadata     = optional(string)
  }))
  default = {}
}

variable "policy_assignments" {
  description = "Configuration for Policy Assignments."
  type = map(object({
    scope                  = string
    policy_definition_name = string
    description            = string
    location               = string
    parameters             = optional(any)
  }))
  default = {}
}

variable "resource_groups" {
  description = "Configuration for Resource Groups."
  type = map(object({
    name     = string
    location = string
    tags     = optional(map(string))
  }))
  default = {}
}

