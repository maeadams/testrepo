variable "resource_group_name" {
  description = "The name of the resource group where monitoring resources will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region where monitoring resources will be deployed."
  type        = string
}

variable "workspace_config" {
  description = "Configuration for Log Analytics Workspace"
  type = object({
    name              = string
    sku               = string
    retention_in_days = optional(number)
    tags              = optional(map(string))
  })
}

variable "action_groups" {
  description = "Configuration for Action Groups"
  type = map(object({
    name       = string
    short_name = string
    email_receivers = optional(list(object({
      name                    = string
      email_address           = string
      use_common_alert_schema = optional(bool, true)
    })), [])
    sms_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })), [])
    webhook_receivers = optional(list(object({
      name        = string
      service_uri = string
    })), [])
    tags = optional(map(string))
  }))
  default = {}
}

variable "metric_alerts" {
  description = "Configuration for metric alerts"
  type = map(object({
    name                = string
    resource_group_name = string
    scopes              = list(string)
    description         = string
    criteria = object({
      metric_namespace = string
      metric_name      = string
      aggregation      = string
      operator         = string
      threshold        = number
    })
    frequency        = string
    window_size      = string
    severity         = number
    action_group_ids = list(string)
  }))
  default = {}
}

variable "query_alerts" {
  description = "Configuration for log query alerts"
  type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    description         = string
    query               = string
    frequency           = string
    time_window         = string
    severity            = number
    threshold           = number
    action_group_ids    = list(string)
  }))
  default = {}
}

variable "service_health_alerts" {
  description = "Configuration for Service Health alerts"
  type = map(object({
    name    = string
    enabled = bool
    scopes  = list(string)
    criteria = object({
      service_health = list(object({
        locations = list(string)
        events    = list(string)
      }))
    })
    action_group_ids = list(string)
    tags             = optional(map(string))
  }))
  default = {}
}

variable "data_collection_rules" {
  description = "Configuration for Data Collection Rules"
  type = map(object({
    name = string
    destinations = list(object({
      name                  = string
      workspace_resource_id = string
    }))
    data_sources = optional(object({
      windows_event_log = optional(list(object({
        name           = string
        streams        = list(string)
        x_path_queries = list(string)
      })), [])
    }))
    tags = optional(map(string))
  }))
  default = {}
}

variable "diagnostic_settings" {
  description = "Configuration for Diagnostic Settings"
  type = map(object({
    name                       = string
    target_resource_id         = string
    log_analytics_workspace_id = string
    logs = list(object({
      category = string
      enabled  = bool
      retention_policy = object({
        enabled = bool
        days    = number
      })
    }))
    metrics = list(object({
      category = string
      enabled  = bool
      retention_policy = object({
        enabled = bool
        days    = number
      })
    }))
  }))
  default = {}
}
