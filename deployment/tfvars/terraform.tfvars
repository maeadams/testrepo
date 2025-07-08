# =============================================================================
# TERRAFORM.TFVARS - AZURE COMMERCIAL LANDING ZONE POC
# =============================================================================

# -----------------------------------------------------------------------------
# Basic Configuration
# -----------------------------------------------------------------------------
location                  = "France Central"
subscription_id           = "7445ae6f-a879-4d74-9a49-eebda848dc6c"
admin_user_principal_name = "maeva@MngEnvMCAP334656.onmicrosoft.com"
# -----------------------------------------------------------------------------
# Resource Organization (EXACT STRUCTURE)
# -----------------------------------------------------------------------------
management_group_config = {
  "root" = {
    name         = "mg-cltroot-POCpub-1"
    display_name = "CLT Root POC France Central"
    parent_id    = null
  }
}

# TARGET RESOURCE GROUP STRUCTURE (6 groups)
resource_groups = {
  # On-Premises Integration
  "rg_onprem" = {
    name     = "on-prem"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "OnPremiseSimulation"
    }
  }

  # Network Hub (Central Hub) - Consolidates network, security, admin, shared services
  "rg_network_hub" = {
    name     = "network-hub"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "CentralizedHubInfrastructure"
    }
  }

  # Frontend Exposed Connected Apps
  "rg_fe_exposed_apps" = {
    name     = "fe-exposed-connected-apps"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "FrontendExposedApplications"
    }
  }

  # Backend Exposed Connected Apps
  "rg_be_exposed_apps" = {
    name     = "be-exposed-connected-apps"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "BackendExposedDatabases"
    }
  }

  # Frontend Non-Exposed Connected Apps
  "rg_fe_nonexposed_apps" = {
    name     = "fe-non-exposed-connected-apps"
    location = "France Central"
    tags = {
      Environment = "POC"
      Purpose     = "FrontendNonExposedApplications"
    }
  }
}
  