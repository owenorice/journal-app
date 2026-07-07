#!/bin/bash
# init-environment.sh

# Exit immediately if a command fails
set -e

echo "Step 1: Authenticating with Azure..."
az login

# -- 1) BOOTSTRAP --
echo "Step 2: Creating Bootstrap Infrastructure (Storage for Terraform)..."
cd ../terraform/bootstrap
terraform init
terraform plan
terraform apply

# Get the storage accunt name and update the main provider file automatically
STORAGE_NAME=$(terraform output -raw storage_account_name)
cd ..

# -- 2) CONFIG --
echo "Step 3: Configuring Main Terraform Backend..."
# This uses 'perl' to swap the placeholder in providers.tf with the real name
perl -i -pe "s/REPLACE_WITH_YOUR_OUTPUT_NAME/$STORAGE_NAME/g" providers.tf

# -- 3) MAIN INFRASTRUCTURE --
echo "Step 4: Initialising main infrastructure..."
terraform init #executed in root dir


echo "Setup complete!"
echo "You can now run terraform apply to build, or push to GitHub to trigger the build action."