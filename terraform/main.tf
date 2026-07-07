resource "azurerm_resource_group" "main" {
  name = "rg-journal-app"
  location = var.location
}