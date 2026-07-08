terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.80.0"
    }
  }

  backend "azurerm" {
    resource_group_name = "rg-journal-app"
    storage_account_name = "tfstatestorage545c52b8" // replace var in prod, check init-environemnt for default ~~ Unique ID, use ./init-environment.sh to populate + execute initialisation correctly
    container_name = "tfstate"
    key = "journal-app.tfstate"
    use_oidc = true
  }

}

provider "azurerm" {
  # Configuration options
  features {}
  use_oidc = true
}
