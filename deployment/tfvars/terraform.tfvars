resource_groups = {
    rg1 = {
        name     = "rg1"
        location = "France Central"
        tags     = {
            environment = "demo"
        }
    }
}

managed_identities = {
    identity1 = {
        name                = "msi-demo"
        resource_group_name = "rg1"
        location            = "France Central"
        tags                = {
            environment = "demo"
        }
    }
}
 app_service_plans = {
  "service_plan_demo" = {
    name                = "demo-plan"
    resource_group_name = "rg1" # ✅ REQUIRED
    location            = "France Central"            # ✅ REQUIRED
    os_type             = "Windows"
    sku_name            = "S1"
    tags = {
      Environment = "demo"
    }
  }
}
web_apps = {
 webapp_demo = {
    name                = "demo-webapp-azure"
    resource_group_name = "rg1"
    location            = "France Central"
    service_plan_key    = "service_plan_demo" # ✅ REQUIRED
    os_type                       = "Windows"
    https_only                    = false
    site_config = {
      always_on                = true
      http2_enabled            = true
      dotnet_framework_version = "v6.0"
    }
    identity_type = "SystemAssigned" 

    tags = {
      Environment = "demo"
    }
  }
}