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

variable "secret_officers" {
  type        = map(string)
  description = "Principals that can write/delete secrets (deployers, pipelines)."
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

# Deployers/pipelines that need to write secrets.
resource "azurerm_role_assignment" "secret_officer" {
  for_each             = var.secret_officers
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

# NOTE: Secret VALUES are intentionally NOT managed by Terraform.
# - Infrastructure (vault, network, RBAC) is provisioned here.
# - Secret seeding is an out-of-band operation (human via private endpoint, or
#   a dedicated seeding job inside the network).
# This keeps secret material out of Terraform state and respects the
# vault's private-only network posture.

variable "seeded_secret_names" {
  type        = list(string)
  description = "Names of secrets that will be seeded out-of-band into this vault. Used to construct stable URIs for downstream services to reference."
  default     = []
}

output "id" {
  value = azurerm_key_vault.this.id
}

output "uri" {
  value = azurerm_key_vault.this.vault_uri
}

# Construct versionless secret URIs without managing the secret values themselves.
# Downstream services (e.g. Container Apps) reference these URIs; the actual
# secret values are seeded out-of-band.
output "secret_uris" {
  value = {
    for name in var.seeded_secret_names :
    name => "${azurerm_key_vault.this.vault_uri}secrets/${name}"
  }
}
