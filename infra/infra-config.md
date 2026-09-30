# Azure Resources Config

## Environment Info

| Property | Value |
|----------|-------|
| Subscription ID | `7baa8cc0-a4ab-43ed-a4e0-4eaec0aa2d81` |
| Resource Group | `rg-photoalbum` |
| Location | `eastus2` |

## Resource List

| Resource Type | Name | Region | Config Details |
|---------------|------|---------|----------------|
| Azure Container App | `azcazzmmsndycvmyw` | eastus2 | URL: `https://azcazzmmsndycvmyw.greenpond-9b380b67.eastus2.azurecontainerapps.io`; container name `photoalbum`; ingress target port 8080; user-assigned identity `azidzzmmsndycvmyw` |
| Azure Container Apps Environment | `azcaezzmmsndycvmyw` | eastus2 | Consumption workload profile; logs sent to Log Analytics workspace `azlawzzmmsndycvmyw` |
| Azure Container Registry | `azcrzzmmsndycvmyw` | eastus2 | Login server: `azcrzzmmsndycvmyw.azurecr.io`; SKU Basic |
| Azure Database for PostgreSQL Flexible Server | `azpgzzmmsndycvmyw` | eastus2 | FQDN: `azpgzzmmsndycvmyw.postgres.database.azure.com`; PostgreSQL 17; database `photoalbum`; Microsoft Entra authentication enabled; passwordless DB role `aad_photoalbumdb` |
| User-Assigned Managed Identity | `azidzzmmsndycvmyw` | eastus2 | Client ID: `1d418bfa-fc3f-4e51-a9e0-bf361da529a9`; used by the Container App for passwordless PostgreSQL access |
| Log Analytics Workspace | `azlawzzmmsndycvmyw` | eastus2 | Workspace for Container Apps application logs; 30-day retention |
| Service Connector (linker) | `photoalbumdb` | eastus2 | Passwordless link Container App → PostgreSQL. Injects `spring.datasource.url`, `spring.datasource.username`, `spring.datasource.azure.passwordless-enabled`, `spring.cloud.azure.credential.client-id`, `spring.cloud.azure.credential.managed-identity-enabled` |
