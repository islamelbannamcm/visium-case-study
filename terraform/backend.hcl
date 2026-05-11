# Passed via: terraform init -backend-config=backend.hcl
# Real values are injected by the workflow from GitHub Actions variables.
resource_group_name  = "rg-tfstate-shared"
storage_account_name = "sttfstateusecase01"
container_name       = "tfstate"
key                  = "usecase-private-01/terraform.tfstate"
use_azuread_auth     = true
