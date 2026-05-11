subscription_id = "00000000-0000-0000-0000-000000000000"
location        = "switzerlandnorth"
environment     = "dev"
workload        = "usecase"

hub = {
  subscription_id     = "11111111-1111-1111-1111-111111111111"
  resource_group_name = "rg-hub-connectivity-prd"
  vnet_name           = "vnet-hub-prd"
  vnet_id             = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-hub-connectivity-prd/providers/Microsoft.Network/virtualNetworks/vnet-hub-prd"
  private_dns_zones = {
    blob          = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-hub-dns-prd/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    key_vault     = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-hub-dns-prd/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    acr           = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-hub-dns-prd/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
    container_app = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-hub-dns-prd/providers/Microsoft.Network/privateDnsZones/privatelink.switzerlandnorth.azurecontainerapps.io"
  }
}
