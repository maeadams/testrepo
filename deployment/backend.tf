terraform {
  backend "azurerm" {
    key      = "terraform.tfstate"
    use_oidc = true
  }
}



# backend.tf

# Example backend configuration for Azure Blob Storage
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "tfstate-rg"
#     storage_account_name = "tfstatestorageaccount" # Must be globally unique
#     container_name       = "tfstate"
#     key                  = "terraform.tfstate"
#   }
# }

# This file is a placeholder.
# Configure your desired backend for Terraform state management.
# For production, using a remote backend like Azure Blob Storage is highly recommended
# to ensure state locking, versioning, and secure access.
#
# To initialize with a backend, you would run:
# terraform init \
#   -backend-config="resource_group_name=myrg" \
#   -backend-config="storage_account_name=mystorageaccount" \
#   -backend-config="container_name=tfstate" \
#   -backend-config="key=prod.terraform.tfstate"
#
# Or, you can create a backend.conf file with these settings.
