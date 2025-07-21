module "resource_organization" {
  source = "../modules/resource-organization"
  resource_groups = var.resource_groups
  
}

module "identity" {
  source = "../modules/identity"
  managed_identities = var.managed_identities
  depends_on = [ module.resource_organization ]
}

module "web_apps" {
    source = "../modules/application"
    web_apps = var.web_apps
    app_service_plans = var.app_service_plans
    depends_on = [ module.resource_organization]
}