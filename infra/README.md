# Photo Album — Azure Infrastructure (Bicep)

Infrastructure as Code for hosting the Photo Album Spring Boot application on Azure
Container Apps with Azure Database for PostgreSQL flexible server.

## Architecture

```text
Users → Azure Container Apps (Photo Album) → Azure Database for PostgreSQL Flexible Server
             │                                          ▲
             ├→ Azure Container Registry (app image)     │ managed identity (passwordless)
             └→ Log Analytics workspace (app logs)  ─────┘
```

## Resources

| Resource | Module | Purpose |
|----------|--------|---------|
| Log Analytics workspace | `modules/loganalytics.bicep` | Container Apps environment logging |
| User-assigned managed identity | `modules/identity.bicep` | ACR pull + passwordless PostgreSQL access |
| Azure Container Registry (Basic) | `modules/containerregistry.bicep` | Stores the application image; includes the `AcrPull` role assignment for the managed identity |
| Azure Container Apps environment + app | `modules/containerapp.bicep` | Hosts the application (external ingress, CORS enabled) |
| Azure Database for PostgreSQL Flexible Server v17 | `modules/postgresql.bicep` | Application database, Entra auth enabled |

## Naming

All resources are named `az{prefix}{resourceToken}` where
`resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)`.

| Prefix | Resource |
|--------|----------|
| `law` | Log Analytics workspace |
| `id` | User-assigned managed identity |
| `cr` | Container Registry |
| `cae` | Container Apps environment |
| `ca` | Container App |
| `pg` | PostgreSQL flexible server |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `environmentName` | `photoalbum` | Used to build the unique resource token |
| `location` | resource group location | Primary region (`eastus2`) |
| `postgresLocation` | `location` | Region for PostgreSQL (must have quota) |
| `databaseName` | `photoalbum` | Application database name |
| `postgresAdministratorLogin` | `pgadmin` | Local admin login (not used by the app) |
| `postgresAdministratorLoginPassword` | *(secure, generated)* | Generated randomly by the deploy script |
| `entraAdminObjectId` / `entraAdminName` / `entraAdminType` | signed-in user | Microsoft Entra administrator for PostgreSQL |
| `targetPort` | `8080` | Container ingress target port |
| `assignAcrPullRole` | `true` | Create the `AcrPull` role assignment; set to `false` when the deploying principal cannot write role assignments |

Parameter files: `main.parameters.json` (and identical `parameters.json`). Secret and
identity values are supplied by the deployment script at run time and are never stored
in the repository.

## Deploy

```powershell
# Windows
az login
./infra/deploy.ps1
```

```bash
# Linux / macOS
az login
./infra/deploy.sh
```

The scripts:

1. Verify the Azure CLI login and resolve the subscription.
2. Resolve the signed-in principal as the PostgreSQL Microsoft Entra administrator.
3. Generate a random PostgreSQL administrator password (not used by the application).
4. Create/update the resource group and run `az deployment group create`.
5. Install the `serviceconnector-passwordless` extension and create a Service Connector
   connection (`az containerapp connection create postgres-flexible`) so the Container App
   authenticates to PostgreSQL with the user-assigned managed identity.

## Security

- The application uses a **user-assigned managed identity** for PostgreSQL access.
  No database password is configured on the app.
- Service Connector injects the Spring Boot datasource configuration automatically;
  do not set `SPRING_DATASOURCE_*` environment variables manually.
- Anonymous ACR pull is disabled.
- No Key Vault is provisioned because the application stores no secrets.
- No credentials, connection strings, or resource IDs are committed to the repository.

### ACR authentication note

The template assigns the `AcrPull` role to the managed identity when
`assignAcrPullRole=true` (default). Creating role assignments requires
`Microsoft.Authorization/roleAssignments/write`, which a plain `Contributor` does not have.
If the deployment fails for that reason, the deploy scripts automatically retry with
`assignAcrPullRole=false`, which enables the ACR admin user and wires the Container App
registry connection through a declared `acr-password` secret. Once
`User Access Administrator` (or `Role Based Access Control Administrator`) is granted,
re-run the deploy script to switch back to the managed-identity path.

## Post-deployment

Actual provisioned resource names and endpoints are written to `infra/infra-config.md`
after a successful deployment. The Container App initially runs the
`mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` base image; the application
image is pushed to ACR and rolled out during the deployment task.
