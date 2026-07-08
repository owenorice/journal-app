data "azurerm_resource_group" "main" {
  name = "rg-journal-app"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-journalapp"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_container_registry" "acr" {
  name                = "acrjournalapp"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "random_id" "postgres_suffix" {
  byte_length = 4
}

resource "random_password" "postgres_password" {
  length           = 20
  special          = true
  override_special = "!#_"
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                         = "pg-journalapp-${random_id.postgres_suffix.hex}"
  resource_group_name          = data.azurerm_resource_group.main.name
  location                     = data.azurerm_resource_group.main.location
  version                      = "16"
  administrator_login          = "pgadmin"
  administrator_password       = random_password.postgres_password.result
  zone                         = "1"
  storage_mb                   = 32768
  sku_name                     = "B_Standard_B1ms"
  public_network_access_enabled = true
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "journal_app_production"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "db_cache" {
  name      = "journal_app_production_cache"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "db_queue" {
  name      = "journal_app_production_queue"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "db_cable" {
  name      = "journal_app_production_cable"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}


resource "azurerm_service_plan" "app" {
  name                = "asp-journalapp"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-journalapp-${random_id.postgres_suffix.hex}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.app.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                            = false
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = "journal_app:latest"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
  }

  app_settings = {
    "WEBSITES_PORT"                 = "80"
    "RAILS_ENV"                     = "production"
    "RAILS_SERVE_STATIC_FILES"      = "true"
    "RAILS_LOG_TO_STDOUT"           = "true"
    "RAILS_MASTER_KEY"              = var.rails_master_key
    "DATABASE_URL"                  = "postgres://pgadmin:npxfZM%23_mK3JNEtQZbdx@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/journal_app_production?sslmode=require"
    "CACHE_DATABASE_URL"            = "postgres://pgadmin:npxfZM%23_mK3JNEtQZbdx@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/journal_app_production_cache?sslmode=require"
    "QUEUE_DATABASE_URL"            = "postgres://pgadmin:npxfZM%23_mK3JNEtQZbdx@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/journal_app_production_queue?sslmode=require"
    "CABLE_DATABASE_URL"            = "postgres://pgadmin:npxfZM%23_mK3JNEtQZbdx@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/journal_app_production_cable?sslmode=require"
    "JOURNAL_APP_DATABASE_PASSWORD" = random_password.postgres_password.result
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}


output "app_service_url" {
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
  description = "The default URL of the deployed App Service"
}

