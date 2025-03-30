#!/bin/bash

set -euo pipefail

APP_NAME="Foo Application"
RESOURCE_GROUP_NAME="foo-app-rg"
LOCATION="westeurope"
CONTAINER_NAME="tfstate"
TERRAFORM_FOO_APP_SP_NAME="${APP_NAME} SP"
TFVARS_FILE="../terraform/terraform.tfvars"

DRY_RUN=false

function log {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}

function warn {
  echo -e "\033[1;33m[WARN]\033[0m $1"
}

function error_exit {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
  exit 1
}

function destroy {
  if $DRY_RUN; then
    log "[Dry Run] Would delete service principal and resource group."
    exit 0
  fi

  log "Destroying Terraform SP and resource group..."

  APP_ID=$(az ad sp list --display-name "$TERRAFORM_FOO_APP_SP_NAME" --query "[0].appId" -o tsv)
  if [[ -n "$APP_ID" ]]; then
    az ad sp delete --id "$APP_ID" || warn "Failed to delete SP: $APP_ID"
    log "Deleted service principal: $APP_ID"
  else
    warn "Service principal not found."
  fi

  az group delete --name "$RESOURCE_GROUP_NAME" --yes --no-wait || warn "Failed to delete resource group."

  [[ -f "$TFVARS_FILE" ]] && rm "$TFVARS_FILE"
  log "Environment destroyed."
  exit 0
}

# Handle flags
for arg in "$@"; do
  case $arg in
    --destroy)
      destroy
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      ;;
  esac
done

# Check prerequisites
command -v az >/dev/null || error_exit "Azure CLI not found."
command -v jq >/dev/null || error_exit "jq not found."

log "Getting subscription ID..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

log "Creating resource group..."
if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
  warn "Resource group '$RESOURCE_GROUP_NAME' already exists."
else
  if $DRY_RUN; then
    log "[Dry Run] Would create resource group '$RESOURCE_GROUP_NAME' in '$LOCATION'."
  else
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" || error_exit "Failed to create resource group."
  fi
fi

log "Checking for existing service principal..."
if az ad sp list --display-name "$TERRAFORM_FOO_APP_SP_NAME" --query "[0].appId" -o tsv | grep -q .; then
  warn "Service principal '$TERRAFORM_FOO_APP_SP_NAME' already exists. Skipping creation."
  CLIENT_ID=$(az ad sp list --display-name "$TERRAFORM_FOO_APP_SP_NAME" --query "[0].appId" -o tsv)
  TENANT_ID=$(az account show --query tenantId -o tsv)
  warn "You need to manually retrieve the client secret."
  CLIENT_SECRET="<INSERT_YOUR_CLIENT_SECRET>"
else
  if $DRY_RUN; then
    log "[Dry Run] Would create service principal '$TERRAFORM_FOO_APP_SP_NAME'."
    CLIENT_ID="<dry-run-client-id>"
    CLIENT_SECRET="<dry-run-client-secret>"
    TENANT_ID="<dry-run-tenant-id>"
  else
    log "Creating service principal..."
    TERRAFORM_FOO_APP_SP=$(az ad sp create-for-rbac \
      --name "${TERRAFORM_FOO_APP_SP_NAME}" \
      --role="Contributor" \
      --scopes="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}") || error_exit "Failed to create service principal."

    CLIENT_ID=$(echo "$TERRAFORM_FOO_APP_SP" | jq -r '.appId')
    CLIENT_SECRET=$(echo "$TERRAFORM_FOO_APP_SP" | jq -r '.password')
    TENANT_ID=$(echo "$TERRAFORM_FOO_APP_SP" | jq -r '.tenant')
  fi
fi

STORAGE_ACCOUNT_NAME="footerraform$(date +%s)"
log "Creating storage account for Terraform state..."
if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
  warn "Storage account '$STORAGE_ACCOUNT_NAME' already exists."
else
  if $DRY_RUN; then
    log "[Dry Run] Would create storage account '$STORAGE_ACCOUNT_NAME'."
  else
    az storage account create \
      --name "$STORAGE_ACCOUNT_NAME" \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --location "$LOCATION" \
      --sku Standard_LRS || error_exit "Failed to create storage account."
  fi
fi

if $DRY_RUN; then
  log "[Dry Run] Would retrieve storage account key and create blob container '$CONTAINER_NAME'."
else
  STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --query "[0].value" -o tsv)

  log "Creating blob container..."
  az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" || error_exit "Failed to create blob container."
fi

log "Generating terraform.tfvars..."
cat <<EOF > "$TFVARS_FILE"
client_id            = "$CLIENT_ID"
client_secret        = "$CLIENT_SECRET"
tenant_id            = "$TENANT_ID"
subscription_id      = "$SUBSCRIPTION_ID"
resource_group_name  = "$RESOURCE_GROUP_NAME"
resource_group_location = "$LOCATION"
EOF

log "Terraform backend block example:"
cat <<EOF

terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP_NAME"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
    container_name       = "$CONTAINER_NAME"
    key                  = "terraform.tfstate"
  }
}
EOF

if $DRY_RUN; then
  log "Dry run complete. No changes were made."
else
  log "Environment setup complete."
  log "You can now run 'terraform init' to initialize the backend."
  log "To destroy the environment, run the script with the --destroy flag."
fi
