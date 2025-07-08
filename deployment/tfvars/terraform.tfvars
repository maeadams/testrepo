location = "West Europe"
# -----------------------------------------------------------------------------
# Resource Organization (EXACT STRUCTURE)
# -----------------------------------------------------------------------------
# management_group_config = {
#   "root" = {
#     name         = "mg-cltroot-POCpub-1"
#     display_name = "CLT Root POC France Central"
#     parent_id    = null
#   }
# }
# policy_definitions = {
#   "DenyExpensiveVMs" = {
#     policy_type  = "Custom"
#     mode         = "All"
#     display_name = "Deny Expensive VM SKUs"
#     description  = "Prevents deployment of expensive VM SKUs in POC environment"
#     policy_rule = {
#       if = {
#         allOf = [
#           {
#             field  = "type"
#             equals = "Microsoft.Compute/virtualMachines"
#           },
#           {
#             anyOf = [
#               {
#                 field = "Microsoft.Compute/virtualMachines/sku.name"
#                 like  = "Standard_D*_v5"
#               },
#               {
#                 field = "Microsoft.Compute/virtualMachines/sku.name"
#                 like  = "Standard_E*"
#               }
#             ]
#           }
#         ]
#       }
#       then = {
#         effect = "deny"
#       }
#     }
#   }
# }

# policy_assignments = {
#   "DenyExpensiveVMs" = {
#     scope                  = "7445ae6f-a879-4d74-9a49-eebda848dc6c"
#     policy_definition_name = "DenyExpensiveVMs"
#     description            = "Prevent expensive VM deployments"
#     location               = "France Central"
#   }
# }

# # TARGET RESOURCE GROUP STRUCTURE (6 groups)
# resource_groups = {
#   # On-Premises Integration
#   "rg_onprem" = {
#     name     = "on-prem"
#     location = "France Central"
#     tags = {
#       Environment = "POC"
#       Purpose     = "OnPremiseSimulation"
#     }
#   }

#   # Network Hub (Central Hub) - Consolidates network, security, admin, shared services
#   "rg_network_hub" = {
#     name     = "network-hub"
#     location = "France Central"
#     tags = {
#       Environment = "POC"
#       Purpose     = "CentralizedHubInfrastructure"
#     }
#   }

#   # Frontend Exposed Connected Apps
#   "rg_fe_exposed_apps" = {
#     name     = "fe-exposed-connected-apps"
#     location = "France Central"
#     tags = {
#       Environment = "POC"
#       Purpose     = "FrontendExposedApplications"
#     }
#   }

#   # Backend Exposed Connected Apps
#   "rg_be_exposed_apps" = {
#     name     = "be-exposed-connected-apps"
#     location = "France Central"
#     tags = {
#       Environment = "POC"
#       Purpose     = "BackendExposedDatabases"
#     }
#   }

#   # Frontend Non-Exposed Connected Apps
#   "rg_fe_nonexposed_apps" = {
#     name     = "fe-non-exposed-connected-apps"
#     location = "France Central"
#     tags = {
#       Environment = "POC"
#       Purpose     = "FrontendNonExposedApplications"
#     }
#   }
# }
  