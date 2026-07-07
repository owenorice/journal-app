provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "state_rg" {
  name     = "rg-journal-app"
  location = "West Europe"
}

resource "azurerm_storage_account" "state_sa" {
  name                     = "tfstate-storage-${random_id.suffix.hex}" // has to be globally unqiue id
  resource_group_name      = azurerm_resource_group.state_rg.name
  location                 = azurerm_resource_group.state_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "state_container" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state_sa.id
  container_access_type = "private"
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "storage_account_name" {
  value = azurerm_storage_account.state_sa.name
}