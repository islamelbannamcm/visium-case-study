variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "tags" { type = map(string) }
variable "vnet_name" { type = string }
variable "vnet_address_space" { type = list(string) }
variable "subnets" {
  type = map(object({
    address_prefixes                  = list(string)
    delegation                        = optional(string)
    private_endpoint_network_policies = optional(string, "Disabled")
  }))
}
variable "hub" {
  type = object({
    subscription_id     = string
    resource_group_name = string
    vnet_name           = string
    vnet_id             = string
    private_dns_zones = object({
      blob          = string
      key_vault     = string
      acr           = string
      container_app = string
    })
  })
}

resource "azurerm_virtual_network" "spoke" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                              = "snet-${each.key}-${var.name_suffix}"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = each.value.address_prefixes
  private_endpoint_network_policies = each.value.private_endpoint_network_policies

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = "delegation"
      service_delegation {
        name = delegation.value
      }
    }
  }
}

# Default-deny NSG on the private-endpoints subnet. ACA subnet is intentionally
# left without an NSG because Microsoft.App manages required platform rules.
resource "azurerm_network_security_group" "pe" {
  name                = "nsg-private-endpoints-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  security_rule {
    name                       = "AllowVnetInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInBound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.this["private_endpoints"].id
  network_security_group_id = azurerm_network_security_group.pe.id
}

# -----------------------------------------------------------------------------
# Hub <-> Spoke peering
# -----------------------------------------------------------------------------
variable "use_remote_gateways" {
  type        = bool
  description = "Set to true in real deployments with a hub VPN gateway; false for sandbox POCs."
  default     = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.use_remote_gateways
}

# The reverse peering is created in the hub subscription. In a real platform
# it's done by the connectivity team's automation (or via a second provider
# alias here when the spoke team has rights). Kept as a documented placeholder.
# resource "azurerm_virtual_network_peering" "hub_to_spoke" { ... provider = azurerm.hub ... }
