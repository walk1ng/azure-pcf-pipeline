#!/bin/bash
set -e

# get ${OPSMAN_DOMAIN_OR_IP_ADDRESS} from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./resource-terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`

echo "=============================================================================================="
echo "Configuring OpsManager @ https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "=============================================================================================="

#Configure Opsman
om-linux --target https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} -k \
  configure-authentication \
  --username "${PCF_OPSMAN_ADMIN}" \
  --password "${PCF_OPSMAN_ADMIN_PASSWORD}" \
  --decryption-passphrase "${PCF_OPSMAN_ADMIN_PASSWORD}"