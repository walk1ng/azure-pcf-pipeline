#!/bin/bash
set -eu

# get values from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`
AZURE_TERRAFORM_PREFIX=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.pcf_resource_group_name.value'`
BOSH_STORAGE_ACCOUNT_NAME=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.bosh_root_storage_account.value'`
DEPLOYMENT_STORAGE_ACCOUNT_NAME=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.wildcard_vm_storage_account.value'`
DEFAULT_SECURITY_GROUP=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.bosh_deployed_vms_security_group_name.value'`
PCF_SSH_KEY_PUB=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_ssh_public_key.value'`
PCF_SSH_KEY_PRIV=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_ssh_private_key.value'`
NETWORK_NAME=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.network_name.value'`
MANAGEMENT_SUBNET_NAME=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.management_subnet_name.value'`
MANAGEMENT_SUBNET_CIDRS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.management_subnet_cidrs.value[0]'`
MANAGEMENT_SUBNET_GATEWAY=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.management_subnet_gateway.value'`
PAS_SUBNET_NAME=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.pas_subnet_name.value'`
PAS_SUBNET_CIDRS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.pas_subnet_cidrs.value[0]'`
PAS_SUBNET_GATEWAY=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.pas_subnet_gateway.value'`
SERVICES_SUBNET_NAME=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.services_subnet_name.value'`
SERVICES_SUBNET_CIDRS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.services_subnet_cidrs.value[0]'`
SERVICES_SUBNET_GATEWAY=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.services_subnet_gateway.value'`
DNS="168.63.129.16"



echo "=============================================================================================="
echo "Configuring Director @ https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "=============================================================================================="

iaas_configuration=$(
  jq -n \
    --arg subscription_id "${AZURE_SUBSCRIPTION_ID}" \
    --arg tenant_id "${AZURE_TENANT_ID}" \
    --arg client_id "${AZURE_CLIENT_ID}" \
    --arg client_secret "${AZURE_CLIENT_SECRET}" \
    --arg resource_group_name "${AZURE_TERRAFORM_PREFIX}" \
    --arg bosh_storage_account_name "${BOSH_STORAGE_ACCOUNT_NAME}" \
    --arg deployments_storage_account_name "${DEPLOYMENT_STORAGE_ACCOUNT_NAME}" \
    --arg default_security_group "${DEFAULT_SECURITY_GROUP}" \
    --arg ssh_public_key "${PCF_SSH_KEY_PUB}" \
    --arg ssh_private_key "${PCF_SSH_KEY_PRIV}" \
    --arg cloud_storage_type "storage_accounts" \
    --arg environment "${AZURE_ENV}" \
    '{
      "subscription_id": $subscription_id,
      "tenant_id": $tenant_id,
      "client_id": $client_id,
      "client_secret": $client_secret,
      "resource_group_name": $resource_group_name,
      "bosh_storage_account_name": $bosh_storage_account_name,
      "deployments_storage_account_name": $deployments_storage_account_name,
      "default_security_group": $default_security_group,
      "ssh_public_key": $ssh_public_key,
      "ssh_private_key": $ssh_private_key,
      "cloud_storage_type": $cloud_storage_type,
      "environment": $environment
    }'
)

director_configuration=$(
  jq -n \
    '{
      "ntp_servers_string": "0.pool.ntp.org",
      "metrics_ip": "",
      "resurrector_enabled": true,
      "post_deploy_enabled": false,
      "bosh_recreate_on_next_deploy": false,
      "retry_bosh_deploys": false,
      "hm_pager_duty_options": {
        "enabled": false,
      },
      "hm_emailer_options": {
        "enabled": false,
      },
      "blobstore_type": "local",
      "database_type": "internal"
    }'
)

networks_configuration=$(
  jq -n \
    --arg management_subnet_iaas "${NETWORK_NAME}/${MANAGEMENT_SUBNET_NAME}" \
    --arg management_subnet_cidr "${MANAGEMENT_SUBNET_CIDRS}" \
    --arg management_subnet_reserved "10.0.8.1-10.0.8.9" \
    --arg management_subnet_dns "${DNS}" \
    --arg management_subnet_gateway "${MANAGEMENT_SUBNET_GATEWAY}" \
    --arg pas_subnet_iaas "${NETWORK_NAME}/${PAS_SUBNET_NAME}" \
    --arg pas_subnet_cidr "${PAS_SUBNET_CIDRS}" \
    --arg pas_subnet_reserved "10.0.0.1-10.0.0.9" \
    --arg pas_subnet_dns "${DNS}" \
    --arg pas_subnet_gateway "${PAS_SUBNET_GATEWAY}" \
    --arg services_subnet_iaas "${NETWORK_NAME}/${SERVICES_SUBNET_NAME}" \
    --arg services_subnet_cidr "${SERVICES_SUBNET_CIDRS}" \
    --arg services_subnet_reserved "10.0.4.1-10.0.4.9" \
    --arg services_subnet_dns "${DNS}" \
    --arg services_subnet_gateway "${SERVICES_SUBNET_GATEWAY}" \
    '{
      "icmp_checks_enabled": false,
      "networks": [
        {
          "name": "Management",
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $management_subnet_iaas,
              "cidr": $management_subnet_cidr,
              "reserved_ip_ranges": $management_subnet_reserved,
              "dns": $management_subnet_dns,
              "gateway": $management_subnet_gateway,
            }
          ]
        },
        {
          "name": "PAS",
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $pas_subnet_iaas,
              "cidr": $pas_subnet_cidr,
              "reserved_ip_ranges": $pas_subnet_reserved,
              "dns": $pas_subnet_dns,
              "gateway": $pas_subnet_gateway,
            }
          ]
        },
        {
          "name": "Services",
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $services_subnet_iaas,
              "cidr": $services_subnet_cidr,
              "reserved_ip_ranges": $services_subnet_reserved,
              "dns": $services_subnet_dns,
              "gateway": $services_subnet_gateway,
            }
          ]
        }
      ]
    }'
)

network_assignment=$(
  jq -n \
    '{
      "network": {
        "name": "Management"
      }
    }'
)

security_configuration=$(
  jq -n \
    '{
      "generate_vm_passwords": true
    }'
)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --username "$PCF_OPSMAN_ADMIN" \
  --password "$PCF_OPSMAN_ADMIN_PASSWORD" \
  configure-director \
  --iaas-configuration "${iaas_configuration}" \
  --director-configuration "${director_configuration}" \
  --networks-configuration "${networks_configuration}" \
  --network-assignment "${network_assignment}" \
  --security-configuration "${security_configuration}"