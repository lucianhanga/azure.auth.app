terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.1.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "foo-app-rg"
    storage_account_name = "footerraform1743276144"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {} 
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}

# resource "azurerm_resource_group" "rg" {
#   name     = var.resource_group_name
#   location = var.resource_group_location
# }
