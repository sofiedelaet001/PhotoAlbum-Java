<#
.SYNOPSIS
    Provisions the Azure infrastructure for the Photo Album application.

.DESCRIPTION
    Creates (or updates) a resource group and deploys infra/main.bicep using the Azure CLI.
    After provisioning it uses Service Connector to create a passwordless (managed identity)
    connection between the Container App and Azure Database for PostgreSQL flexible server.

.NOTES
    Requires: Azure CLI (az), an authenticated session (az login).
#>

[CmdletBinding()]
param(
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$ResourceGroupName = $(if ($env:AZURE_RESOURCE_GROUP) { $env:AZURE_RESOURCE_GROUP } else { 'rg-photoalbum' }),
    [string]$Location = $(if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { 'eastus2' }),
    [string]$PostgresLocation = $(if ($env:AZURE_POSTGRES_LOCATION) { $env:AZURE_POSTGRES_LOCATION } else { 'eastus2' }),
    [string]$EnvironmentName = $(if ($env:AZURE_ENV_NAME) { $env:AZURE_ENV_NAME } else { 'photoalbum' }),
    [string]$DatabaseName = 'photoalbum',
    [int]$TargetPort = 8080,
    [switch]$SkipServiceConnector
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateFile = Join-Path $scriptDir 'main.bicep'

Write-Host '==> Checking Azure CLI login...' -ForegroundColor Cyan
$account = az account show -o json 2>$null
if (-not $account) {
    throw "Not logged in to Azure. Run 'az login' first."
}
$accountObj = $account | ConvertFrom-Json

if (-not $SubscriptionId) {
    $SubscriptionId = $accountObj.id
}
az account set --subscription $SubscriptionId | Out-Null
Write-Host "    Subscription: $SubscriptionId" -ForegroundColor DarkGray

# Microsoft Entra administrator for PostgreSQL (the current signed-in principal).
$signedInUser = az ad signed-in-user show -o json | ConvertFrom-Json
$entraAdminObjectId = $signedInUser.id
$entraAdminName = if ($signedInUser.userPrincipalName) { $signedInUser.userPrincipalName } else { $signedInUser.displayName }
$entraAdminType = 'User'
Write-Host "    Entra PostgreSQL admin: $entraAdminName" -ForegroundColor DarkGray

# Generate a random administrator password. The application never uses it:
# it authenticates with a user-assigned managed identity.
$bytes = New-Object 'System.Byte[]' 24
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$postgresAdminPassword = ([System.Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', '') + 'Aa1!'

Write-Host "==> Ensuring resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location --output none

Write-Host '==> Validating Bicep template...' -ForegroundColor Cyan
az bicep build --file $templateFile --stdout | Out-Null

$deploymentName = "photoalbum-infra-$(Get-Date -Format 'yyyyMMddHHmmss')"

function Invoke-InfraDeployment {
    param([string]$Name, [bool]$AssignAcrPullRole)

    $assignValue = if ($AssignAcrPullRole) { 'true' } else { 'false' }
    az deployment group create `
        --name $Name `
        --resource-group $ResourceGroupName `
        --template-file $templateFile `
        --parameters `
            environmentName=$EnvironmentName `
            location=$Location `
            postgresLocation=$PostgresLocation `
            databaseName=$DatabaseName `
            targetPort=$TargetPort `
            entraAdminObjectId=$entraAdminObjectId `
            entraAdminName=$entraAdminName `
            entraAdminType=$entraAdminType `
            assignAcrPullRole=$assignValue `
            postgresAdministratorLoginPassword=$postgresAdminPassword `
        --query properties.outputs `
        --output json
}

Write-Host '==> Deploying infrastructure (this can take ~10 minutes)...' -ForegroundColor Cyan
$deployOutputJson = Invoke-InfraDeployment -Name $deploymentName -AssignAcrPullRole $true

if ($LASTEXITCODE -ne 0 -or -not $deployOutputJson) {
    # The deploying principal may not have Microsoft.Authorization/roleAssignments/write
    # (e.g. Contributor without User Access Administrator). Retry without the AcrPull
    # role assignment; the container app then uses ACR admin credentials instead.
    Write-Warning 'Deployment failed. Retrying without the AcrPull role assignment (ACR admin credential fallback)...'
    $deploymentName = "photoalbum-infra-$(Get-Date -Format 'yyyyMMddHHmmss')-noacrrole"
    $deployOutputJson = Invoke-InfraDeployment -Name $deploymentName -AssignAcrPullRole $false
}

if ($LASTEXITCODE -ne 0 -or -not $deployOutputJson) {
    throw 'Infrastructure deployment failed.'
}

$outputs = $deployOutputJson | ConvertFrom-Json

$containerAppName = $outputs.AZURE_CONTAINER_APP_NAME.value
$containerName = $outputs.AZURE_CONTAINER_NAME.value
$postgresServerName = $outputs.AZURE_POSTGRES_SERVER_NAME.value
$identityClientId = $outputs.AZURE_MANAGED_IDENTITY_CLIENT_ID.value
$registryEndpoint = $outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT.value
$appUri = $outputs.AZURE_CONTAINER_APP_URI.value

Write-Host ''
Write-Host '==> Deployment outputs' -ForegroundColor Green
Write-Host "    Container App      : $containerAppName"
Write-Host "    Container App URL  : $appUri"
Write-Host "    Container Registry : $registryEndpoint"
Write-Host "    PostgreSQL server  : $($outputs.AZURE_POSTGRES_FQDN.value)"
Write-Host "    Database           : $($outputs.AZURE_POSTGRES_DATABASE_NAME.value)"

if (-not $SkipServiceConnector) {
    Write-Host ''
    Write-Host '==> Ensuring serviceconnector-passwordless extension...' -ForegroundColor Cyan
    az extension add --name serviceconnector-passwordless --upgrade --only-show-errors 2>$null | Out-Null

    $containerAppId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.App/containerApps/$containerAppName"

    Write-Host '==> Creating passwordless Service Connector connection (Container App -> PostgreSQL)...' -ForegroundColor Cyan
    az containerapp connection create postgres-flexible `
        --connection photoalbumdb `
        --user-identity client-id=$identityClientId subs-id=$SubscriptionId `
        --source-id $containerAppId `
        --tg $ResourceGroupName `
        --server $postgresServerName `
        --database $DatabaseName `
        --client-type springBoot `
        -c $containerName `
        -y

    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Service Connector creation failed. Re-run this script or create the connection manually.'
    }
    else {
        Write-Host '    Passwordless connection created.' -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Provisioning complete.' -ForegroundColor Green
