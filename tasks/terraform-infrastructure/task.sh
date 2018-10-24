#!/bin/bash
set -e

source azure-pcf-pipeline/functions/parse_opsman_image_url_region.sh
ROOT="${PWD}"

ls -lR

# Get image url of opsman according to region
echo "=============================================================================================="
echo "Getting Azure Ops Manager VHD URI from Pivnet YML...."
echo "=============================================================================================="
pcf_opsman_image_vhd=$(parseOpsImageURLWithRegion "${PCF_LOCATION}" "./pivnet-opsman/*Azure.yml")
echo "Found Azure OpsMan Image @ $pcf_opsman_image_vhd ...."

# Enter the terraform resource
cd terraforming-azure

# Download source and uncompress it
mkdir src
tar -xzvf source.tar.gz -C src
cd src/pivotal-cf-terraforming-azure-*/terraforming-pas/

echo "=============================================================================================="
echo "Terraforming Azure resources...."
echo "=============================================================================================="

# Generate tfvars file
cat > terraform.tfvars << EOF
subscription_id       = "${AZURE_SUBSCRIPTION_ID}"
tenant_id             = "${AZURE_TENANT_ID}"
client_id             = "${AZURE_CLIENT_ID}"
client_secret         = "${AZURE_CLIENT_SECRET}"

env_name              = "${PCF_ENV_NAME}"
env_short_name        = "${PCF_SHORT_ENV_NAME}"
location              = "${PCF_LOCATION}"
ops_manager_image_uri = "${pcf_opsman_image_vhd}"
dns_suffix            = "${PCF_DNS_SUFFIX}"
EOF

# Create Azure infrastructure
terraform init
terraform plan -out=plan
terraform apply plan

# copy terraform.tfstate to output directory
cp terraform.tfstate ${ROOT}/terraform-tfstate/
cd ${ROOT}
ls -lR
