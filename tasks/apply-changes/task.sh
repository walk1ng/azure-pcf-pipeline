#!/bin/bash

set -eu

# get values from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`

echo "==========================================================================================================="
echo "Deploying ${DEPLOYMENT_NAME} on @ https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "==========================================================================================================="

om-linux \
  --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
  --skip-ssl-validation \
  --username "${PCF_OPSMAN_ADMIN}" \
  --password "${PCF_OPSMAN_ADMIN_PASSWORD}" \
  apply-changes \
  --ignore-warnings