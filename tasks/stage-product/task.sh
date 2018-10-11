#!/bin/bash

set -eu

# get values from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`

echo "================================================================================================================="
echo "Staging [product: ${PRODUCT_NAME}, version: ${PRODUCT_VERSION}] on Director @ https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "================================================================================================================="

# stage the product
om-linux --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
  --skip-ssl-validation \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  --username "${PCF_OPSMAN_ADMIN}" \
  --password "${PCF_OPSMAN_ADMIN_PASSWORD}" \
  stage-product \
  --product-name "${PRODUCT_NAME}" \
  --product-version "${PRODUCT_VERSION}"