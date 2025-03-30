#!/bin/bash

set -euo pipefail

APP_NAME="AzureAppProxy"
RESOURCE_GROUP_NAME="azure-app-proxy-rg"
LOCATION="westeurope"
VM_SIZE="Standard_B2s"
IMAGE="Win2022Datacenter"
ADMIN_USERNAME="azureuser"
VM_NAME="app-proxy-vm"

# Flags
DRY_RUN=true
RUN_PROVISION=false
RUN_DESTROY=false
POSTFIX=""

# Usage
function usage {
  echo -e "\033[1;36mUsage:\033[0m"
  echo "  $0 --provision --postfix <name> [--no-dry-run]"
  echo "  $0 --destroy --postfix <name> [--no-dry-run]"
  echo "  $0 --help | --usage"
}

# Logging
function log { echo -e "\033[1;34m[INFO]\033[0m $1"; }
function warn { echo -e "\033[1;33m[WARN]\033[0m $1"; }
function error_exit { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

# Args
while [[ $# -gt 0 ]]; do
  case $1 in
    --provision) RUN_PROVISION=true; shift ;;
    --destroy) RUN_DESTROY=true; shift ;;
    --no-dry-run) DRY_RUN=false; shift ;;
    --postfix) POSTFIX="$2"; shift 2 ;;
    --help|--usage) usage; exit 0 ;;
    *) error_exit "Unknown option: $1" ;;
  esac
done

[[ -z "$POSTFIX" ]] && error_exit "Missing required option: --postfix <name>"

# Derived
VM_NAME="${VM_NAME}-${POSTFIX,,}"
PASSWORD="MySecurePassword!$(date +%s)"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Destroy
function destroy {
  log "Destroying resources for VM '$VM_NAME' in group '$RESOURCE_GROUP_NAME'..."
  if $DRY_RUN; then
    log "[Dry Run] Would delete VM and resource group."
  else
    az group delete --name "$RESOURCE_GROUP_NAME" --yes --no-wait
    log "Deletion initiated."
  fi
  exit 0
}

if $RUN_DESTROY; then destroy; fi
if ! $RUN_PROVISION; then usage; exit 1; fi

log "Provisioning App Proxy VM (dry-run: $DRY_RUN)"

# Resource group
if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
  warn "Resource group already exists."
else
  $DRY_RUN && log "[Dry Run] Would create resource group." || \
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
fi

# VM
if $DRY_RUN; then
  log "[Dry Run] Would provision VM '$VM_NAME' of size '$VM_SIZE'"
else
  az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VM_NAME" \
    --image "$IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$PASSWORD" \
    --public-ip-sku Standard \
    --output none \
    --computer-name "appproxy"
  log "VM '$VM_NAME' created."
fi

# Open RDP
if $DRY_RUN; then
  log "[Dry Run] Would open port 3389 for RDP."
else
  az vm open-port --port 3389 --resource-group "$RESOURCE_GROUP_NAME" --name "$VM_NAME"
  log "Port 3389 opened."
fi

# Output info
if ! $DRY_RUN; then
  PUBLIC_IP=$(az vm show -d -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --query publicIps -o tsv)
  log "✅ VM is ready. RDP to: $PUBLIC_IP"
  echo "🔑 Credentials:"
  echo "  Username: $ADMIN_USERNAME"
  echo "  Password: $PASSWORD"
  echo "📦 Download Azure App Proxy Connector inside VM:"
  echo "  https://aka.ms/aadappproxyconnector"
else
  log "✅ Dry run complete. No changes made."
fi
