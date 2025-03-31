#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
VM_NAME="foo-vm"
ANSIBLE_HOSTS_FILE="../ansible/hosts.ini"
TERRAFORM_DIR="../terraform"
SSH_KEY_FILE="$TERRAFORM_DIR/foo-vm-ssh-key.pem"
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
log "Starting Ansible hosts file update using Terraform output..."

# 1. Ensure Terraform output is accessible
log "Reading Terraform outputs from directory: $TERRAFORM_DIR"
cd "$TERRAFORM_DIR"

if ! terraform output &>/dev/null; then
  error_exit "Terraform outputs not found. Make sure 'terraform apply' has been run successfully in $TERRAFORM_DIR."
fi

# 2. Get the public IP
log "Extracting 'public_ip' from Terraform outputs..."
PUBLIC_IP=$(terraform output -raw foo_vm_public_ip)

if [[ -z "$PUBLIC_IP" ]]; then
  error_exit "Terraform output 'public_ip' is empty or not defined."
fi

log "Retrieved public IP: $PUBLIC_IP"

# 3. Update Ansible hosts file
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
