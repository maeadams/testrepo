# =============================================================================
# ROOT MAIN.TF - COMMERCIAL AZURE LANDING ZONE POC
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    pkcs12 = {
      source  = "chilicat/pkcs12"
      version = "~> 0.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.0"
}

# Provider configurations
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

  }
  use_oidc = true
}

provider "azuread" {}
provider "tls" {}
provider "pkcs12" {}
provider "null" {}
provider "random" {}
provider "time" {}

# resource "azurerm_resource_group" "example" {
#   name     = "test2-pipeline-poc"
#   location = var.location
# }

# =============================================================================
# RESOURCE ORGANIZATION MODULE
# =============================================================================
module "resource_organization" {
  source                  = "../modules/resource-organization"
  management_group_config = var.management_group_config
  policy_definitions      = var.policy_definitions
  policy_assignments      = var.policy_assignments
  resource_groups         = var.resource_groups
}
# =============================================================================
# FRONTEND EXPOSED WEB APPLICATIONS MODULE
# =============================================================================
module "fe_exposed_webapp" {
  source = "./modules/application"

  # ---------------------------------------------------------------------------
  # 1.  Web-app objects to deploy in THIS module instance
  # ---------------------------------------------------------------------------
  # Pass ONLY the exposed app, so every service_plan_key you reference
  # exists in the accompanying app_service_plans map.
  web_apps = {
    webapp_exposed = var.web_apps["webapp_exposed"]
  }

  # ---------------------------------------------------------------------------
  # 2.  App-Service Plan(s) used by those web-apps
  # ---------------------------------------------------------------------------
  app_service_plans = {
    asp_fe_exposed = merge(
      var.app_service_plans["asp_fe_exposed"],
      {
        # Override RG / location so the plan is created in the correct scope
        resource_group_name = module.resource_organization.resource_group_names["rg_fe_exposed_apps"]
        location            = var.location
      }
    )
  }

  # ---------------------------------------------------------------------------
  # 3.  Networking inputs required for VNet-integration & private endpoints
  # ---------------------------------------------------------------------------
  subnet_ids           = module.network.subnet_ids
  private_dns_zone_ids = module.network.private_dns_zone_ids

  depends_on = [
    module.resource_organization,
    module.network
  ]
}
module "network" {
  source = "../modules/network"

  resource_group_name              = module.resource_organization.resource_group_names["rg_network_hub"]
  location                         = var.location
  hub_vnet_config                  = var.hub_vnet_config
  spoke_vnet_configs               = var.spoke_vnet_configs
  subnet_configs                   = var.subnet_configs
  nsg_rules                        = var.nsg_rules
  route_tables                     = var.route_tables
  vpn_gateway_config               = var.vpn_gateway_config
  private_endpoint_configs         = var.private_endpoint_configs
  bastion_host_config              = var.bastion_host_config
  eventgrid_source_arm_resource_id = var.eventgrid_source_arm_resource_id

  depends_on = [module.resource_organization]
}