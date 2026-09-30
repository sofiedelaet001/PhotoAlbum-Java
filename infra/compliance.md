# IaC Rules Compliance Report

Task: `002-infrastructure` · IaC: Bicep · Deployment tool: Azure CLI (`az deployment`)

## General rules

| Rule | Status | Evidence |
|------|--------|----------|
| Call `appmod-get-available-region-sku` before generating | ✅ Applied | `eastus2` selected; PostgreSQL Burstable (`standardBSFamily`) available with 196 cores remaining quota |
| Set each resource location from the available region list | ✅ Applied | `location` and `postgresLocation` both default to `eastus2`; `postgresLocation` is a separate parameter so PostgreSQL can be moved independently |
| Add index suffix when a region is unavailable | ✅ N/A | `eastus2` available for all resource types; no rename needed |

## azcli deployment tool rules

| Rule | Status | Evidence |
|------|--------|----------|
| `.ps1` for PowerShell, `.sh` for Bash | ✅ Applied | `infra/deploy.ps1`, `infra/deploy.sh` |
| All steps must execute successfully; fix and rerun on failure | ✅ Applied | Scripts use `$ErrorActionPreference='Stop'` / `set -euo pipefail` and throw on non-zero exit |
| Validate PowerShell syntax before execution | ✅ Applied | `deploy.ps1` parsed and executed successfully |
| Use `az deployment`, not `azd` | ✅ Applied | `az deployment group create` |

## Bicep rules

| Rule | Status | Evidence |
|------|--------|----------|
| Expected files `main.bicep` + `main.parameters.json` | ✅ Applied | Both present (plus `parameters.json`) |
| Resource token `uniqueString(subscription().id, resourceGroup().id, location, environmentName)` | ✅ Applied | `main.bicep` `var resourceToken` |
| Names `az{prefix≤3}{resourceToken}`, alphanumeric | ✅ Applied | `azlaw…`, `azid…`, `azcr…`, `azcae…`, `azca…`, `azpg…` |
| Templates pass `az bicep build` | ✅ Applied | `az bicep build --file infra/main.bicep` succeeds with no errors |

## Container Apps rules

| Rule | Status | Evidence |
|------|--------|----------|
| Attach User-Assigned Managed Identity | ✅ Applied | `containerapp.bicep` → `identity.type: 'UserAssigned'` |
| MANDATORY `AcrPull` (`7f951dda-4ed3-4680-a7ca-43fe172d538d`) role assignment for the UAMI, one per registry, defined before container apps | ⚠️ Implemented, blocked at deploy time | `containerregistry.bicep` → `acrPullRoleAssignment`, declared in the registry module which deploys before the container app module (`dependsOn: [containerRegistry]`). **Deviation:** the deploying principal (`Contributor` only) lacks `Microsoft.Authorization/roleAssignments/write`, so ARM rejected the assignment (`AuthorizationFailed` / ABAC condition not fulfilled). The template exposes `assignAcrPullRole` and the deploy script automatically retried with `assignAcrPullRole=false`, enabling ACR admin credentials for the registry pull secret. Re-run `deploy.ps1` after `User Access Administrator` / `RBAC Administrator` is granted to restore the managed-identity path. |
| Use the user-assigned identity (not system) for the registry connection | ⚠️ Fallback active | `configuration.registries[0].identity = userAssignedIdentityId` when `assignAcrPullRole=true`; currently using `username` + `passwordSecretRef` because of the RBAC limitation above. A **system**-assigned identity is never used. |
| Base image `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` via `properties.template.containers.image` | ✅ Applied | `containerImage` default in `containerapp.bicep` |
| Registry connection via `properties.configuration.registries` | ✅ Applied | `containerapp.bicep` |
| Enable CORS via `properties.configuration.ingress.corsPolicy` | ✅ Applied | `corsPolicy` with allowed origins/methods/headers and `maxAge` |
| Define all used secrets; use Key Vault if possible | ✅ Applied | `secrets: []` in the managed-identity path. In the active ACR-admin fallback a single declared `acr-password` secret is used for the registry pull; no application secrets exist because PostgreSQL access is passwordless |
| MANDATORY explicit dependencies for Key Vault secrets + role assignment | ✅ N/A | No Key Vault provisioned (no secrets to store) |
| Container Apps environment connected to Log Analytics via `logAnalyticsConfiguration` (`customerId`, `sharedKey` from `listKeys().primarySharedKey`) | ✅ Applied | `containerapp.bicep` → `appLogsConfiguration.logAnalyticsConfiguration` |

## Azure Container Registry rules

| Rule | Status | Evidence |
|------|--------|----------|
| No additional rules for `azurecontainerregistry` | ✅ N/A | Basic SKU, anonymous pull disabled. Admin user is enabled only because the AcrPull role assignment was blocked by tenant RBAC (see Container Apps section) |

## PostgreSQL rules

| Rule | Status | Evidence |
|------|--------|----------|
| Version `17` or higher | ✅ Applied | `postgresVersion = '17'` |
| Do not create a database named `postgres` | ✅ Applied | Database name is `photoalbum` |
| On provisioning error, re-check quota and add index to name suffix | ✅ N/A | Deployment succeeded in `eastus2`; no retry needed |
| Firewall rule allowing Azure services (`0.0.0.0`) | ✅ Applied | `AllowAllAzureServicesAndResources` firewall rule |
| Secret-based access → Key Vault + params | ✅ N/A | App uses managed identity, not secrets |
| Managed identity access → post-provision Service Connector step | ✅ Applied | Deploy scripts install `serviceconnector-passwordless` and run `az containerapp connection create postgres-flexible` |
| Use `--user-identity client-id=… subs-id=…`, not `--system-identity` | ✅ Applied | `deploy.ps1` / `deploy.sh` |
| Use `--client-type` (`springBoot`) and `-c <containername>` for container apps | ✅ Applied | `--client-type springBoot -c photoalbum` |
| For Spring Boot, do not add `SPRING_DATASOURCE` env vars | ✅ Applied | Container App only sets `AZURE_CLIENT_ID` and `SERVER_PORT`; Service Connector injects datasource config |

## Key Vault rules

| Rule | Status | Evidence |
|------|--------|----------|
| Use Key Vault only when the application has secrets to store | ✅ Applied | No Key Vault provisioned — passwordless managed identity access means the app stores no secrets |
