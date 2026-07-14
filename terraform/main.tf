data "azurerm_resource_group" "main" {
  name = "rg-journal-app"
}

// --- Networks ---
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

// --- Containers ---
resource "azurerm_container_registry" "acr" {
  name                = "acrjournalapp"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = false
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
    always_on                            = true
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
    "AZURE_STORAGE_ACCOUNT_NAME"    = azurerm_storage_account.uploads.name
    "AZURE_STORAGE_CONTAINER"       = azurerm_storage_container.uploads.name
    "AZURE_STORAGE_ACCESS_KEY"      = azurerm_storage_account.uploads.primary_access_key
    "SOLID_QUEUE_IN_PUMA"           = "true"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

// --- Blob storage for Active Storage uploads ---
resource "azurerm_storage_account" "uploads" {
  name                            = "stjournalapp${random_id.postgres_suffix.hex}"
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = data.azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "uploads" {
  name                  = "activestorage"
  storage_account_id    = azurerm_storage_account.uploads.id
  container_access_type = "private"
}

// NOTE: shared-key auth instead of a managed-identity role assignment: the
// pipeline's service principal lacks Microsoft.Authorization/roleAssignments/write.
// To go secretless later, grant the app's identity "Storage Blob Data Contributor"
// on this account and swap the AZURE_STORAGE_ACCESS_KEY app setting for
// use_managed_identities in config/storage.yml.

output "app_service_url" {
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
  description = "The default URL of the deployed App Service"
}

// --- Postgres ---
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


