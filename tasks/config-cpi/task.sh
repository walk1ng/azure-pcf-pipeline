#!/bin/bash
set -e

# get values from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./resource-terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`

echo "=============================================================================================="
echo "Configuring CPI release on Opsman VM @ ${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "=============================================================================================="

echo "Generate ssh login key."
terraform output -state=./resource-terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_ssh_private_key.value' > opsman
echo "Set proper permission to key."
chmod 700 opsman
echo "Upload cpi to opsman vm."
scp -o StrictHostKeyChecking=no -i opsman ./resource-bosh-cpi-validate-release/bosh-azure-cpi ubuntu@${OPSMAN_DOMAIN_OR_IP_ADDRESS}:/home/ubuntu/cpi
echo "Replace the default cpi which comes from opsman."
ssh -i opsman ubuntu@${OPSMAN_DOMAIN_OR_IP_ADDRESS} 'sudo mv /var/tempest/internal_releases/cpi /var/tempest/internal_releases/cpi.origin'
ssh -i opsman ubuntu@${OPSMAN_DOMAIN_OR_IP_ADDRESS} 'sudo mv cpi /var/tempest/internal_releases/'
ssh -i opsman ubuntu@${OPSMAN_DOMAIN_OR_IP_ADDRESS} 'sudo chown tempest-web:tempest-web /var/tempest/internal_releases/cpi'
