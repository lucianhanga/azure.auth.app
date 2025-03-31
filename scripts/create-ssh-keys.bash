#!/bin/bash

set -euo pipefail

# Define the path to the Terraform folder and key names
TERRAFORM_FOLDER="../terraform"
PRIVATE_KEY_NAME="foo-vm-ssh-key.pem"
PUBLIC_KEY_NAME="foo-vm-ssh-key.pub"

# Ensure the Terraform folder exists
if [[ ! -d "$TERRAFORM_FOLDER" ]]; then
  echo "[ERROR] Terraform folder '$TERRAFORM_FOLDER' does not exist."
  exit 1
fi

# Define the full paths for the keys
PRIVATE_KEY_PATH="$TERRAFORM_FOLDER/$PRIVATE_KEY_NAME"
PUBLIC_KEY_PATH="$TERRAFORM_FOLDER/$PUBLIC_KEY_NAME"

# Check if the keys already exist
if [[ -f "$PRIVATE_KEY_PATH" || -f "$PUBLIC_KEY_PATH" ]]; then
  echo "[WARN] SSH key pair already exists:"
  [[ -f "$PRIVATE_KEY_PATH" ]] && echo "  - Private key: $PRIVATE_KEY_PATH"
  [[ -f "$PUBLIC_KEY_PATH" ]] && echo "  - Public key: $PUBLIC_KEY_PATH"
  echo "[INFO] Skipping key generation."
  exit 0
fi

# Generate the SSH key pair
echo "[INFO] Generating SSH key pair..."
ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_PATH" -N "" -C "foo-vm-key" || {
  echo "[ERROR] Failed to generate SSH key pair."
  exit 1
}

# Rename the public key to match the desired name
mv "${PRIVATE_KEY_PATH}.pub" "$PUBLIC_KEY_PATH"

# Output success message
echo "[INFO] SSH key pair generated successfully:"
echo "  - Private key: $PRIVATE_KEY_PATH"
echo "  - Public key: $PUBLIC_KEY_PATH"
