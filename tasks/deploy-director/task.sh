#!/bin/bash
set -e

# get values from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`

echo "=============================================================================================="
echo "Deploying Director @ https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "=============================================================================================="

# Apply Changes in Opsman

om-linux --target https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} -k \
  --username "${PCF_OPSMAN_ADMIN}" \
  --password "${PCF_OPSMAN_ADMIN_PASSWORD}" \
  apply-changes