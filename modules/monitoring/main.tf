# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = var.workspace_config.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.workspace_config.sku
  retention_in_days   = lookup(var.workspace_config, "retention_in_days", null)
  tags                = lookup(var.workspace_config, "tags", null)
}

# Action Groups
resource "azurerm_monitor_action_group" "action_group" {
  for_each = var.action_groups

  name                = each.value.name
  resource_group_name = var.resource_group_name
  short_name          = each.value.short_name
  tags                = lookup(each.value, "tags", null)

  dynamic "email_receiver" {
    for_each = lookup(each.value, "email_receivers", [])
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }

  dynamic "sms_receiver" {
    for_each = lookup(each.value, "sms_receivers", [])
    content {
      name         = sms_receiver.value.name
      country_code = sms_receiver.value.country_code
      phone_number = sms_receiver.value.phone_number
    }
  }

  dynamic "webhook_receiver" {
    for_each = lookup(each.value, "webhook_receivers", [])
    content {
      name        = webhook_receiver.value.name
      service_uri = webhook_receiver.value.service_uri
    }
  }
}

#   CONDITIONAL: Only create DCR if data collection rules are defined


#   ADD: Metric Alerts
resource "azurerm_monitor_metric_alert" "metric_alerts" {
  for_each = var.metric_alerts

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  scopes              = each.value.scopes
  description         = each.value.description
  frequency           = each.value.frequency
  window_size         = each.value.window_size
  severity            = each.value.severity

  criteria {
    metric_namespace = each.value.criteria.metric_namespace
    metric_name      = each.value.criteria.metric_name
    aggregation      = each.value.criteria.aggregation
    operator         = each.value.criteria.operator
    threshold        = each.value.criteria.threshold
  }

  action {
    action_group_id = each.value.action_group_ids[0]
  }

  depends_on = [azurerm_monitor_action_group.action_group]
}

#   ADD: Scheduled Query Rules
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "query_alerts" {
  for_each = var.query_alerts

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  description         = each.value.description

  evaluation_frequency = each.value.frequency
  window_duration      = each.value.time_window
  severity             = each.value.severity

  criteria {
    query                   = each.value.query
    time_aggregation_method = "Count"
    threshold               = each.value.threshold
    operator                = "GreaterThan"
  }

  scopes = [azurerm_log_analytics_workspace.workspace.id]

  action {
    action_groups = each.value.action_group_ids
  }

  depends_on = [azurerm_log_analytics_workspace.workspace]
}

#   ADD: Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "diagnostic_settings" {
  for_each = var.diagnostic_settings

  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = each.value.logs
    content {
      category = enabled_log.value.category
    }
  }

  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value.category
      enabled  = metric.value.enabled
    }
  }
}

# Service Health Alerts - Using global location
resource "azurerm_monitor_activity_log_alert" "service_health_alert" {
  for_each = var.service_health_alerts

  name                = each.value.name
  resource_group_name = var.resource_group_name
  scopes              = each.value.scopes
  description         = "Service Health Alert for ${try(join(", ", each.value.criteria.service_health[0].services), "All Services")} in ${try(join(", ", each.value.criteria.service_health[0].locations), "All Regions")}"
  enabled             = each.value.enabled
  location            = "global" # Must be "global" for activity log alerts
  tags                = lookup(each.value, "tags", null)

  criteria {
    category = "ServiceHealth"
    # The service_health block is directly under criteria
    service_health {
      events    = lookup(each.value.criteria.service_health[0], "events", [])
      locations = lookup(each.value.criteria.service_health[0], "locations", [])
      # Remove services completely as "all" is not a valid service name
      # services  = lookup(each.value.criteria.service_health[0], "services", [])
    }
  }

  action {
    action_group_id = each.value.action_group_ids[0]
  }
}

# Data Collection Rule -   DISABLED for now due to payload issues
/*
resource "azurerm_monitor_data_collection_rule" "data_collection_rule" {
  for_each = var.data_collection_rules

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "Windows"
  
  destinations {
    log_analytics {
      workspace_resource_id = each.value.destinations[0].workspace_resource_id
      name                  = each.value.destinations[0].name
    }
  }
  
  data_sources {
    windows_event_log {
      name           = "WindowsSecurityEvents"
      streams        = ["Microsoft-SecurityEvent"]
      x_path_queries = ["Security!*[System[(EventID=4624 or EventID=4625)]]"]
    }
  }
  
  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = [each.value.destinations[0].name]
  }
  
  tags = lookup(each.value, "tags", null)
}
*/
