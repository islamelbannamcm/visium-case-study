variable "subscription_id" {
  type        = string
  description = "Subscription where the spoke is deployed."
}

variable "location" {
  type        = string
  description = "Azure region for the workload."
  default     = "switzerlandnorth"
}

variable "environment" {
  type        = string
  description = "Environment short name (dev, prd)."
  validation {
    condition     = contains(["dev", "tst", "prd"], var.environment)
    error_message = "environment must be one of: dev, tst, prd."
  }
}

variable "workload" {
  type        = string
  description = "Workload short name, used in resource naming."
  default     = "usecase"
}

variable "hub" {
  description = "Hub connectivity inputs (provided by the platform team)."
  type = object({
    subscription_id     = string
    resource_group_name = string
    vnet_name           = string
    vnet_id             = string
    private_dns_zones = object({
      blob          = string # resource ID of privatelink.blob.core.windows.net
      key_vault     = string # resource ID of privatelink.vaultcore.azure.net
      acr           = string # resource ID of privatelink.azurecr.io
      container_app = string # resource ID of privatelink.<region>.azurecontainerapps.io
    })
  })
}

variable "container_image" {
  type        = string
  description = "Initial container image tag for the app (real deploys are done by the app pipeline)."
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "use_remote_gateways" {
  type        = bool
  description = "Set true with a real hub VPN gateway; false for sandbox POCs."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default = {
    managed_by = "terraform"
    workload   = "usecase-private-01"
  }
}
