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
  source          = "./modules/resource-organization"
  resource_groups = var.resource_groups
}
module "web_app" {
  source = "./modules/application"
  web_apps = {
    app_service_plans = var.app_service_plans
    web_apps          = var.web_apps
  }
}
module "network" {
  source = "./modules/network"

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