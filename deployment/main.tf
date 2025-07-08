# =============================================================================
# ROOT MAIN.TF - COMMERCIAL AZURE LANDING ZONE POC
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    # azuread = {
    #   source  = "hashicorp/azuread"
    #   version = "~> 2.0"
    # }
    # tls = {
    #   source  = "hashicorp/tls"
    #   version = "~> 4.0"
    # }
    # pkcs12 = {
    #   source  = "chilicat/pkcs12"
    #   version = "~> 0.2"
    # }
    # null = {
    #   source  = "hashicorp/null"
    #   version = "~> 3.0"
    # }
    # random = {
    #   source  = "hashicorp/random"
    #   version = "~> 3.0"
    # }
    # time = {
    #   source  = "hashicorp/time"
    #   version = "~> 0.9"
    # }
  }
  required_version = ">= 1.0"
}

# Provider configurations
provider "azurerm" {
  features {
    # key_vault {
    #   purge_soft_delete_on_destroy    = true
    #   recover_soft_deleted_key_vaults = true
    # }
    # resource_group {
    #   prevent_deletion_if_contains_resources = false
    # }

  }
  use_oidc = true
}

# provider "azuread" {}
# provider "tls" {}
# provider "pkcs12" {}
# provider "null" {}
# provider "random" {}
# provider "time" {}

# =============================================================================
# RANDOM SUFFIX GENERATION
# =============================================================================


# module "resource_organization" {
#   source = "../modules/resource-organization"

#   management_group_config = var.management_group_config
#   policy_definitions      = var.policy_definitions
#   policy_assignments      = var.policy_assignments
#   resource_groups         = var.resource_groups
# }

resource "azurerm_resource_group" "example" {
  name     = "test-pipeline-poc"
  location = var.location
}