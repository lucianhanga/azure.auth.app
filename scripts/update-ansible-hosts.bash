#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
RESOURCE_GROUP="foo-app-rg"
VM_NAME="foo-vm"
ANSIBLE_HOSTS_FILE="../ansible/hosts.ini"
SSH_KEY_FILE="../terraform/foo-vm-ssh-key.pem"
ANSIBLE_USER="azureuser"
PYTHON_PATH="/usr/bin/python3"
GROUP_HEADER="[azure]"

# === FUNCTIONS ===
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

# === BEGIN ===
log "Starting Ansible hosts file update process for VM '$VM_NAME'..."

# 1. Check if VM exists
log "Checking if VM '$VM_NAME' exists in resource group '$RESOURCE_GROUP'..."
if ! az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  error_exit "VM '$VM_NAME' does not exist in resource group '$RESOURCE_GROUP'."
fi
log "VM '$VM_NAME' found."

# 2. Check VM status
log "Checking VM power state..."
VM_STATUS=$(az vm get-instance-view --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" \
  --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" -o tsv)

log "VM power state is: $VM_STATUS"
if [[ "$VM_STATUS" != "VM running" ]]; then
  error_exit "VM '$VM_NAME' is not running. Please start it before running this script."
fi

# 3. Retrieve public IP address
log "Fetching NIC attached to VM..."
NIC_ID=$(az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" --query "networkProfile.networkInterfaces[0].id" -o tsv)
NIC_NAME=$(basename "$NIC_ID")
log "NIC ID: $NIC_ID"
log "NIC Name: $NIC_NAME"

log "Retrieving IP configuration for NIC..."
IP_CONFIG_NAME=$(az network nic show --name "$NIC_NAME" --resource-group "$RESOURCE_GROUP" --query "ipConfigurations[0].name" -o tsv)
log "IP Configuration Name: $IP_CONFIG_NAME"

log "Retrieving public IP ID from NIC..."
PUBLIC_IP_ID=$(az network nic show \
  --name "$NIC_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "ipConfigurations[0].publicIpAddress.id" -o tsv)

if [[ -z "$PUBLIC_IP_ID" ]]; then
  error_exit "No public IP is associated with NIC '$NIC_NAME'. Make sure the VM has a public IP."
fi
log "Public IP Resource ID: $PUBLIC_IP_ID"

log "Retrieving Public IP address value..."
PUBLIC_IP=$(az network public-ip show --ids "$PUBLIC_IP_ID" --query "ipAddress" -o tsv)

if [[ -z "$PUBLIC_IP" ]]; then
  error_exit "Failed to retrieve public IP address for VM '$VM_NAME'."
fi

log "Public IP address retrieved: $PUBLIC_IP"

# 4. Update Ansible hosts file
log "Preparing to update Ansible inventory at '$ANSIBLE_HOSTS_FILE'..."

# Backup
log "Creating backup of hosts file at '${ANSIBLE_HOSTS_FILE}.bak'..."
cp "$ANSIBLE_HOSTS_FILE" "${ANSIBLE_HOSTS_FILE}.bak"

# Define updated entry
UPDATED_ENTRY="$VM_NAME ansible_host=$PUBLIC_IP ansible_user=$ANSIBLE_USER ansible_ssh_private_key_file=$SSH_KEY_FILE ansible_python_interpreter=$PYTHON_PATH"
log "New Ansible host entry:"
echo "  $UPDATED_ENTRY"

# Ensure group header exists
if ! grep -qF "$GROUP_HEADER" "$ANSIBLE_HOSTS_FILE"; then
  log "Group header '$GROUP_HEADER' not found in hosts file. Adding it..."
  echo -e "\n$GROUP_HEADER" >> "$ANSIBLE_HOSTS_FILE"
fi

# Replace or insert entry
if grep -qE "^$VM_NAME\s+" "$ANSIBLE_HOSTS_FILE"; then
  log "Host entry for '$VM_NAME' already exists. Updating IP..."
  sed -i.bak "s|^$VM_NAME\s\+.*|$UPDATED_ENTRY|" "$ANSIBLE_HOSTS_FILE"
else
  log "Adding new host entry under group '$GROUP_HEADER'..."
  sed -i "/$GROUP_HEADER/a $UPDATED_ENTRY" "$ANSIBLE_HOSTS_FILE"
fi

log "✅ Ansible hosts file updated successfully!"
