locals {
  # Consistent naming convention: <type>-<workload>-<env>-<region-short>-<NN>
  region_short = {
    switzerlandnorth = "chn"
    westeurope       = "weu"
    northeurope      = "neu"
  }[var.location]

  name_suffix = "${var.workload}-${var.environment}-${local.region_short}-01"

  tags = merge(var.tags, {
    environment = var.environment
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# Networking: spoke VNet, subnets, NSGs, hub peering
# -----------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  name_suffix         = local.name_suffix
  tags                = local.tags

  vnet_name          = "vnet-${var.workload}-private-01"
  vnet_address_space = ["10.0.0.0/24"]

  subnets = {
    # ACA internal env requires a dedicated subnet, delegated, /27 minimum (workload profiles).
    container_app = {
      address_prefixes = ["10.0.0.0/27"]
      delegation       = "Microsoft.App/environments"
    }
    # Private endpoints for storage, key vault, ACR.
    private_endpoints = {
      address_prefixes                  = ["10.0.0.32/27"]
      private_endpoint_network_policies = "Enabled"
    }
  }

  hub = var.hub

  use_remote_gateways = var.use_remote_gateways
}

# -----------------------------------------------------------------------------
# Identity: one UAMI per role (least-privilege)
# -----------------------------------------------------------------------------
module "identity" {
  source = "./modules/identity"

  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  name_suffix         = local.name_suffix
  tags                = local.tags
}

# -----------------------------------------------------------------------------
# Storage: media files, private endpoint, public access disabled
# -----------------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  resource_group_name  = azurerm_resource_group.this.name
  location             = var.location
  name_suffix          = local.name_suffix
  tags                 = local.tags
  private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_id        = var.hub.private_dns_zones.blob

  # Grant the app's UAMI data-plane access only (no control-plane role).
  blob_data_contributors = {
    app = module.identity.app_identity_principal_id
  }
}

# -----------------------------------------------------------------------------
# Key Vault: app secrets, RBAC mode, private endpoint
# -----------------------------------------------------------------------------
module "key_vault" {
  source = "./modules/key_vault"

  resource_group_name        = azurerm_resource_group.this.name
  location                   = var.location
  name_suffix                = local.name_suffix
  tags                       = local.tags
  private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
  private_dns_zone_id        = var.hub.private_dns_zones.key_vault

  # App reads its own secrets only.
  secret_readers = {
    app = module.identity.app_identity_principal_id
  }
}

# -----------------------------------------------------------------------------
# Container App: internal ingress, MI-based ACR pull, KV secret references
# -----------------------------------------------------------------------------
module "container_app" {
  source = "./modules/container_app"

  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  name_suffix         = local.name_suffix
  tags                = local.tags

  infrastructure_subnet_id = module.networking.subnet_ids["container_app"]
  private_dns_zone_id      = var.hub.private_dns_zones.container_app

  app_identity_id          = module.identity.app_identity_id
  app_identity_client_id   = module.identity.app_identity_client_id
  app_identity_principal_id = module.identity.app_identity_principal_id

  container_image = var.container_image

  # Secrets are mounted by referencing Key Vault — value never enters Terraform state.
  key_vault_id = module.key_vault.id
  secret_refs = {
    "db-connection-string" = module.key_vault.secret_uris["db-connection-string"]
  }

  # Env vars pointing the app at the private storage account.
  storage_account_name = module.storage.account_name
  storage_container    = module.storage.media_container_name
}
