variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "tags" { type = map(string) }
variable "infrastructure_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "app_identity_id" { type = string }
variable "app_identity_client_id" { type = string }
variable "app_identity_principal_id" { type = string }
variable "container_image" { type = string }
variable "key_vault_id" { type = string }
variable "secret_refs" {
  type    = map(string)
  default = {}
}
variable "storage_account_name" { type = string }
variable "storage_container" { type = string }

# Log Analytics for ACA env (required).
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Internal ACA environment: VNet-integrated, no public endpoints.
resource "azurerm_container_app_environment" "this" {
  name                       = "cae-${var.name_suffix}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tags                       = var.tags
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = true # internal-only ingress (no public IP)

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

# DNS A record for the env's default domain is created in the hub's
# privatelink.<region>.azurecontainerapps.io zone by the platform automation.

resource "azurerm_container_app" "this" {
  name                         = "ca-app-${var.name_suffix}"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.app_identity_id]
  }

  # Secret references resolve at runtime via the workload's UAMI — values
  # never enter Terraform state or the container image.
  dynamic "secret" {
    for_each = var.secret_refs
    content {
      name                = secret.key
      key_vault_secret_id = secret.value
      identity            = var.app_identity_id
    }
  }

  ingress {
    external_enabled           = false # internal ingress only
    target_port                = 8000
    transport                  = "auto"
    allow_insecure_connections = false
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 5

    container {
      name   = "fastapi"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.app_identity_client_id
      }
      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = var.storage_account_name
      }
      env {
        name  = "STORAGE_CONTAINER"
        value = var.storage_container
      }
      env {
        name        = "DB_CONNECTION_STRING"
        secret_name = "db-connection-string"
      }
    }
  }

  lifecycle {
    # The image tag is owned by the application deployment pipeline (out of scope).
    ignore_changes = [template[0].container[0].image]
  }
}

output "fqdn" {
  value = azurerm_container_app.this.ingress[0].fqdn
}
