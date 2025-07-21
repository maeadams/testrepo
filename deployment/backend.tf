terraform {
  backend "azurerm" {
    resource_group_name  = "edf-poc"
    storage_account_name = "staedfpoc" # Must be globally unique
    container_name       = "poc-edf"
    key                  = "terraform.tfstate"
  }
}