variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "secret_readers" {
  type        = map(string)
  description = "Map of role-assignment-name => principal_id. Keys are static so the plan is deterministic."
  default     = {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = "kv-${substr(var.name_suffix, 0, 18)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 30
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-${azurerm_key_vault.this.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "hub-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

# Least-privilege: the app reads its own secrets only.
resource "azurerm_role_assignment" "secret_user" {
  for_each             = var.secret_readers
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

# Placeholder secret. Real secret values are written out-of-band (e.g. by an
# admin or a separate seeding workflow) so they never appear in Terraform state.
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = "REPLACE_ME"
  key_vault_id = azurerm_key_vault.this.id

  lifecycle {
    ignore_changes = [value]
  }
}

output "id" {
  value = azurerm_key_vault.this.id
}

output "uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "secret_uris" {
  value = {
    "db-connection-string" = azurerm_key_vault_secret.db_connection_string.versionless_id
  }
}
