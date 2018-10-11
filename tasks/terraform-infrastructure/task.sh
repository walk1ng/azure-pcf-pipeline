#!/bin/bash
set -e

ROOT="${PWD}"

# Enter the terraform resource
cd terraforming-azure

# Generate tfvars file
cat > terraform.tfvars << EOF
subscription_id       = "${AZURE_SUBSCRIPTION_ID}"
tenant_id             = "${AZURE_TENANT_ID}"
client_id             = "${AZURE_CLIENT_ID}"
client_secret         = "${AZURE_CLIENT_SECRET}"

env_name              = "${PCF_ENV_NAME}"
env_short_name        = "${PCF_SHORT_ENV_NAME}"
location              = "${PCF_LOCATION}"
ops_manager_image_uri = "${PCF_OPSMAN_IMAGE_URI}"
dns_suffix            = "${PCF_DNS_SUFFIX}"
EOF

# Create Azure infrastructure
terraform init
terraform plan -out=plan
terraform apply plan

ls -l
ls -l ${ROOT}
cp terraform.tfstate ${ROOT}/terraform-state-output/
ls -l ${ROOT}/terraform-state-output
