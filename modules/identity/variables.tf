variable "custom_roles" {
  description = "Custom RBAC role definitions"
  type = map(object({
    name        = string
    description = string
    permissions = list(object({
      actions          = list(string)
      not_actions      = list(string)
      data_actions     = list(string)
      not_data_actions = list(string)
    }))
    assignable_scopes = list(string)
  }))
}

variable "role_assignments" {
  description = "Map of role assignments to create"
  type = map(object({
    name                 = optional(string)
    scope                = string
    role_definition_id   = optional(string) # ✅ Made optional
    role_definition_name = optional(string) # ✅ Added optional role_definition_name
    principal_id         = string
  }))
  default = {}
}

variable "managed_identities" {
  description = "Managed identity configurations"
  type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    tags                = optional(map(string))
  }))
}

variable "identity_providers" {
  description = "OIDC/SAML provider configurations for creating App Registrations."
  type = map(object({
    name          = string
    redirect_uris = list(string)
    required_resource_access = object({
      resource_app_id = string
      resource_access = object({
        id   = string
        type = string
      })
    })
    issuer            = optional(string)
    allowed_audiences = optional(list(string))
    type              = optional(string)
  }))
}

variable "application_owner_object_id" {
  description = "The Object ID of the user or service principal to be assigned as the owner of the created App Registrations."
  type        = string
  nullable    = false
}

#   ADD: Random suffix variable
variable "random_suffix" {
  description = "Random suffix for unique resource naming (passed from root module)"
  type        = string
}
