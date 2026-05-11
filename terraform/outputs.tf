output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "container_app_fqdn" {
  description = "Internal FQDN of the FastAPI app (resolvable only inside the corporate network)."
  value       = module.container_app.fqdn
}

output "storage_account_name" {
  value = module.storage.account_name
}

output "key_vault_uri" {
  value = module.key_vault.uri
}

output "app_identity_client_id" {
  value = module.identity.app_identity_client_id
}
