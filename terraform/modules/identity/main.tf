variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "tags" { type = map(string) }

# One UAMI for the application. Additional UAMIs (e.g. for jobs or sidecars)
# would be added here following the same pattern — never reuse identities
# across workloads.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-app-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

output "app_identity_id" {
  value = azurerm_user_assigned_identity.app.id
}

output "app_identity_principal_id" {
  value = azurerm_user_assigned_identity.app.principal_id
}

output "app_identity_client_id" {
  value = azurerm_user_assigned_identity.app.client_id
}
