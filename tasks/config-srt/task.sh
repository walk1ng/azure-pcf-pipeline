#!/bin/bash
set -eu

source azure-pcf-pipeline/functions/generate_cert.sh

# get values from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`
WEB_LB_NAME=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.web_lb_name.value'`
WEB_LB_PUBLIC_IP=`terraform state show -state=./terraform-tfstate/terraform.tfstate azurerm_public_ip.web-lb-public-ip | grep '^ip_address' | awk '{print $3}'`
SYSTEM_DOMAIN="system.${WEB_LB_PUBLIC_IP}.xip.io"
APPS_DOMAIN="apps.${WEB_LB_PUBLIC_IP}.xip.io"

echo "=============================================================================================="
echo "Configuring Pivotal Small Footprint PAS on @ https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "=============================================================================================="

credhub_encryption_keys_json="{
  \"name\": \"credhubkey1\",
  \"key\":{
      \"secret\": \"credhubsecret1abcdef\"
   },
  \"primary\": true
}"
credhub_encryption_keys_json="[$credhub_encryption_keys_json]"

saml_cert_domains=(
  "*.${SYSTEM_DOMAIN}"
  "*.login.${SYSTEM_DOMAIN}"
  "*.uaa.${SYSTEM_DOMAIN}"
)
saml_certificates=$(generate_cert "${saml_cert_domains[*]}")
SAML_SSL_CERT=$(echo $saml_certificates | jq --raw-output '.certificate')
SAML_SSL_PRIVATE_KEY=$(echo $saml_certificates | jq --raw-output '.key')

poe_ssl_cert_domains=(
  "*.${SYSTEM_DOMAIN}"
  "*.${APPS_DOMAIN}"
  "*.login.${SYSTEM_DOMAIN}"
  "*.uaa.${SYSTEM_DOMAIN}"
)
certificate=$(generate_cert "${poe_ssl_cert_domains[*]}")
pcf_ert_ssl_cert=`echo $certificate | jq '.certificate'`
pcf_ert_ssl_key=`echo $certificate | jq '.key'`
networking_poe_ssl_certs_json="[
  {
    \"name\": \"Certificate 1\",
    \"certificate\": {
      \"cert_pem\": $pcf_ert_ssl_cert,
      \"private_key_pem\": $pcf_ert_ssl_key
    }
  }
]"

# network
cf_network=$(
  jq -n \
    '
    {
      "network": {
        "name": "PAS",
      },
      "other_availability_zones": [
        {"name": "null"}
      ],
      "singleton_availability_zone": {
        "name": "null"
      }
    }
    '
)

# properties
cf_properties=$(
  jq -n \
    --arg system_domain "$SYSTEM_DOMAIN" \
    --arg apps_domain "$APPS_DOMAIN" \
    --arg saml_cert_pem "$SAML_SSL_CERT" \
    --arg saml_key_pem "$SAML_SSL_PRIVATE_KEY" \
    --arg mysql_monitor_recipient_email "$MYSQL_MONITOR_RECIPIENT_EMAIL" \
    --argjson networking_poe_ssl_certs "$networking_poe_ssl_certs_json" \
    --argjson credhub_encryption_keys "$credhub_encryption_keys_json" \
    '
    {
      # Domains
      ".cloud_controller.system_domain": {
        "value": $system_domain
      },
      ".cloud_controller.apps_domain": {
        "value": $apps_domain
      },
      # Networking
      ".properties.networking_poe_ssl_certs": {
        "value": $networking_poe_ssl_certs
      },
      ".properties.haproxy_forward_tls": {
          "value": "disable"
      },
      ".properties.route_services.enable.ignore_ssl_cert_verification": {
          "value": false
      },
      # Application Security Groups
      ".properties.security_acknowledgement": {
        "value": "X"
      },
      # UAA
      ".uaa.service_provider_key_credentials": {
        value: {
          "cert_pem": $saml_cert_pem,
          "private_key_pem": $saml_key_pem
        }
      },
      # Credhub
      ".properties.credhub_key_encryption_passwords": {
        "value": $credhub_encryption_keys
      },
      # Internal MySQL
      ".mysql_monitor.recipient_email": { 
        "value" : $mysql_monitor_recipient_email 
      }
    }
    '
)

# resources
cf_resources=$(
  jq -n \
    --arg web_lb_name "$WEB_LB_NAME" \
    '
    {
      "backup-prepare": {
        "instances": "automatic",
        "persistent_disk": {
          "size_mb": "automatic"
        },
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      },
      "blobstore": {
        "instances": "automatic",
        "persistent_disk": {
          "size_mb": "automatic"
        },
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      },
      "compute": {
        "instances": "automatic",
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      },
      "control": {
        "instances": "automatic",
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      },
      "database": {
        "instances": "automatic",
        "persistent_disk": {
          "size_mb": "automatic"
        },
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      },
      "ha_proxy": {
        "instances": "automatic",
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      },
      "mysql_monitor": {
        "instances": "automatic",
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      },
      "router": {
        "instances": "automatic",
        "instance_type": {
          "id": "automatic"
        },
        "elb_names": [
          $web_lb_name
        ],
        "internet_connected": false
      },
      "tcp_router": {
        "instances": 0,
        "persistent_disk": {
          "size_mb": "automatic"
        },
        "instance_type": {
          "id": "automatic"
        },
        "internet_connected": false
      }
    }
    '
)

# errands
cf_guid=`om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --client-id "$OPSMAN_CLIENT_ID" \
  --client-secret "$OPSMAN_CLIENT_SECRET" \
  --username "$PCF_OPSMAN_ADMIN" \
  --password "$PCF_OPSMAN_ADMIN_PASSWORD" \
  curl \
    -path /api/v0/staged/products \
    -s \
  | jq -r '.[] | select (.type == "cf") | .guid'`

errands_config=$(
  jq -n \
  '
  {
    "errands": [
      {
        "name": "smoke_tests",
        "post_deploy": "default"
      },
      {
        "name": "push-usage-service",
        "post_deploy": false
      },
      {
        "name": "push-apps-manager",
        "post_deploy": false
      },
      {
        "name": "deploy-notifications",
        "post_deploy": false
      },
      {
        "name": "deploy-notifications-ui",
        "post_deploy": false
      },
      {
        "name": "deploy-autoscaler",
        "post_deploy": false
      },
      {
        "name": "test-autoscaling",
        "post_deploy": false
      },
      {
        "name": "nfsbrokerpush",
        "post_deploy": false
      },
      {
        "name": "delete-pivotal-account",
        "post_deploy": false
      }
    ]
  }
  '
)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --client-id "$OPSMAN_CLIENT_ID" \
  --client-secret "$OPSMAN_CLIENT_SECRET" \
  --username "$PCF_OPSMAN_ADMIN" \
  --password "$PCF_OPSMAN_ADMIN_PASSWORD" \
  curl \
    -x PUT \
    --path /api/v0/staged/products/$cf_guid/errands \
    -d "$errands_config" \
    -s

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username "$PCF_OPSMAN_ADMIN" \
  --password "$PCF_OPSMAN_ADMIN_PASSWORD" \
  --skip-ssl-validation \
  configure-product \
  --product-name cf \
  --product-properties "$cf_properties" \
  --product-network "$cf_network" \
  --product-resources "$cf_resources"