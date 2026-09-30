#!/usr/bin/env bash
# Provisions the Azure infrastructure for the Photo Album application.
# Requires: Azure CLI (az) with an authenticated session (az login).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/main.bicep"

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-photoalbum}"
LOCATION="${AZURE_LOCATION:-eastus2}"
POSTGRES_LOCATION="${AZURE_POSTGRES_LOCATION:-eastus2}"
ENVIRONMENT_NAME="${AZURE_ENV_NAME:-photoalbum}"
DATABASE_NAME="${AZURE_POSTGRES_DATABASE_NAME:-photoalbum}"
TARGET_PORT="${AZURE_TARGET_PORT:-8080}"
SKIP_SERVICE_CONNECTOR="${SKIP_SERVICE_CONNECTOR:-false}"

echo "==> Checking Azure CLI login..."
if ! az account show -o none 2>/dev/null; then
  echo "Not logged in to Azure. Run 'az login' first." >&2
  exit 1
fi

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
az account set --subscription "${SUBSCRIPTION_ID}"
echo "    Subscription: ${SUBSCRIPTION_ID}"

ENTRA_ADMIN_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv)"
ENTRA_ADMIN_NAME="$(az ad signed-in-user show --query userPrincipalName -o tsv)"
echo "    Entra PostgreSQL admin: ${ENTRA_ADMIN_NAME}"

# Random administrator password; the application uses managed identity instead.
POSTGRES_ADMIN_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 28)Aa1!"

echo "==> Ensuring resource group '${RESOURCE_GROUP}' in '${LOCATION}'..."
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none

echo "==> Validating Bicep template..."
az bicep build --file "${TEMPLATE_FILE}" --stdout >/dev/null

DEPLOYMENT_NAME="photoalbum-infra-$(date +%Y%m%d%H%M%S)"

deploy_infra() {
  az deployment group create \
    --name "$1" \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "${TEMPLATE_FILE}" \
    --parameters \
      environmentName="${ENVIRONMENT_NAME}" \
      location="${LOCATION}" \
      postgresLocation="${POSTGRES_LOCATION}" \
      databaseName="${DATABASE_NAME}" \
      targetPort="${TARGET_PORT}" \
      entraAdminObjectId="${ENTRA_ADMIN_OBJECT_ID}" \
      entraAdminName="${ENTRA_ADMIN_NAME}" \
      entraAdminType="User" \
      assignAcrPullRole="$2" \
      postgresAdministratorLoginPassword="${POSTGRES_ADMIN_PASSWORD}" \
    --query properties.outputs \
    --output json
}

echo "==> Deploying infrastructure (this can take ~10 minutes)..."
set +e
OUTPUTS="$(deploy_infra "${DEPLOYMENT_NAME}" true)"
DEPLOY_RC=$?
set -e

if [ "${DEPLOY_RC}" -ne 0 ] || [ -z "${OUTPUTS}" ]; then
  # The deploying principal may lack Microsoft.Authorization/roleAssignments/write.
  # Retry without the AcrPull role assignment (ACR admin credential fallback).
  echo "WARNING: deployment failed; retrying without the AcrPull role assignment..." >&2
  DEPLOYMENT_NAME="photoalbum-infra-$(date +%Y%m%d%H%M%S)-noacrrole"
  OUTPUTS="$(deploy_infra "${DEPLOYMENT_NAME}" false)"
fi

CONTAINER_APP_NAME="$(echo "${OUTPUTS}" | jq -r '.AZURE_CONTAINER_APP_NAME.value')"
CONTAINER_NAME="$(echo "${OUTPUTS}" | jq -r '.AZURE_CONTAINER_NAME.value')"
POSTGRES_SERVER_NAME="$(echo "${OUTPUTS}" | jq -r '.AZURE_POSTGRES_SERVER_NAME.value')"
IDENTITY_CLIENT_ID="$(echo "${OUTPUTS}" | jq -r '.AZURE_MANAGED_IDENTITY_CLIENT_ID.value')"
APP_URI="$(echo "${OUTPUTS}" | jq -r '.AZURE_CONTAINER_APP_URI.value')"
REGISTRY_ENDPOINT="$(echo "${OUTPUTS}" | jq -r '.AZURE_CONTAINER_REGISTRY_ENDPOINT.value')"

echo ""
echo "==> Deployment outputs"
echo "    Container App      : ${CONTAINER_APP_NAME}"
echo "    Container App URL  : ${APP_URI}"
echo "    Container Registry : ${REGISTRY_ENDPOINT}"
echo "    PostgreSQL server  : ${POSTGRES_SERVER_NAME}"
echo "    Database           : ${DATABASE_NAME}"

if [ "${SKIP_SERVICE_CONNECTOR}" != "true" ]; then
  echo ""
  echo "==> Ensuring serviceconnector-passwordless extension..."
  az extension add --name serviceconnector-passwordless --upgrade --only-show-errors >/dev/null 2>&1 || true

  CONTAINER_APP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.App/containerApps/${CONTAINER_APP_NAME}"

  echo "==> Creating passwordless Service Connector connection (Container App -> PostgreSQL)..."
  az containerapp connection create postgres-flexible \
    --connection photoalbumdb \
    --user-identity client-id="${IDENTITY_CLIENT_ID}" subs-id="${SUBSCRIPTION_ID}" \
    --source-id "${CONTAINER_APP_ID}" \
    --tg "${RESOURCE_GROUP}" \
    --server "${POSTGRES_SERVER_NAME}" \
    --database "${DATABASE_NAME}" \
    --client-type springBoot \
    -c "${CONTAINER_NAME}" \
    -y
fi

echo ""
echo "Provisioning complete."
