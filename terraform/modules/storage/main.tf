variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "blob_data_contributors" {
  type        = map(string)
  description = "Map of role-assignment-name => principal_id."
  default     = {}
}

resource "azurerm_storage_account" "this" {
  name                = replace("st${var.name_suffix}", "-", "")
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false # AAD only — no access keys
  public_network_access_enabled   = false # no public internet, ever
  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 30 }
  }
}

resource "azurerm_storage_container" "media" {
  name                  = "media"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# Private endpoint for the blob subresource. The DNS A record in the hub's
# central private DNS zone is created automatically by the platform's
# Policy `deployIfNotExists` (per the brief).
resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${azurerm_storage_account.this.name}-blob"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "hub-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

# Least-privilege data-plane role: read/write blobs in this account only.
resource "azurerm_role_assignment" "blob_data_contributor" {
  for_each             = var.blob_data_contributors
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

output "account_name" {
  value = azurerm_storage_account.this.name
}

output "media_container_name" {
  value = azurerm_storage_container.media.name
}
