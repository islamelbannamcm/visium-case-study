# Visium Senior Cloud Engineer — Case Study

Terraform code and a GitOps workflow to deploy a containerized FastAPI application
to a private Azure VNet (`10.0.0.0/24`, `vnet-usecase-private-01`) peered to a
pre-existing hub.

## Architecture summary

| Concern | Choice |
|---|---|
| Compute | Azure Container Apps — **internal** environment (no public IP) |
| Container registry | Azure Container Registry, Premium SKU, private endpoint |
| Storage | Storage account (StorageV2), public access disabled, private endpoint |
| Secrets | Azure Key Vault, RBAC mode, private endpoint, no access keys |
| Identity | One **User-Assigned Managed Identity per workload role** (app, ACR pull, KV reader, storage data) |
| Inbound access | Hub VPN → hub VNet → peering → ACA internal ingress |
| Name resolution | Records created in **central Private DNS zones in the hub** (automated) |
| State | Azure Storage backend, AAD auth, blob lease lock, versioning + soft delete |
| CI/CD auth | GitHub Actions OIDC → federated User-Assigned MI (no stored secrets) |

The application is reachable **only** from clients on the corporate network
(on-prem via VPN, or other spokes via the hub). No service has a public endpoint.

## Repository layout

```
terraform/
  main.tf                root composition
  variables.tf           input variables
  outputs.tf             outputs
  providers.tf           provider + backend config
  backend.hcl            backend values (per environment)
  envs/dev.tfvars        environment values
  modules/
    networking/          vnet, subnets, NSGs, peering, private endpoints, DNS A records
    identity/            user-assigned managed identities + role assignments
    container_app/       ACA environment (internal) + container app
    storage/             storage account + blob container + private endpoint
    key_vault/           key vault + private endpoint + RBAC
.github/workflows/
  terraform.yml          plan on PR, apply on main (OIDC auth, environment gate)
```

## How it runs (GitOps)

1. PR opened → workflow runs `fmt`, `validate`, `plan`. Plan posted to the PR.
2. PR merged to `main` → workflow runs `apply` against the `prod` GitHub Environment
   (requires reviewer approval).
3. No secrets are stored in GitHub. The runner authenticates to Azure via OIDC,
   assuming a federated User-Assigned Managed Identity with the minimum RBAC
   needed to manage the resources in this repo's scope.

## Assumptions

- A hub VNet exists with the VPN gateway and central Private DNS zones
  (`privatelink.blob.core.windows.net`, `privatelink.vaultcore.azure.net`,
  `privatelink.azurecr.io`, `privatelink.<region>.azurecontainerapps.io`).
  DNS A records for private endpoints are created by an existing automation
  (Azure Policy `deployIfNotExists` or an Event Grid + Function pattern).
- The hub resource group, hub VNet name, and hub subscription ID are passed in
  as variables.
- The container image is built and pushed to ACR by a separate application
  pipeline (out of scope per the brief: "application deployment excluded").
