#!/bin/bash

set -eu

# get values from terraform.tfstate
OPSMAN_DOMAIN_OR_IP_ADDRESS=`terraform output -state=./terraform-tfstate/terraform.tfstate -json | jq -r '.ops_manager_public_ip.value'`

echo "=============================================================================================="
echo "Uploading product, stemcell to @ https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} ..."
echo "=============================================================================================="

STEMCELL_VERSION=$(
  cat ./pivnet-product/metadata.json |
  jq --raw-output \
    '
    [
      (.Dependencies // [])[]
      | select(.Release.Product.Name | contains("Stemcells"))
      | .Release.Version
    ]
    | map(split(".") | map(tonumber))
    | transpose | transpose
    | max // empty
    | map(tostring)
    | join(".")
    '
)

if [ -n "$STEMCELL_VERSION" ]; then
  diagnostic_report=$(
    om-linux \
      --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
      --client-id "${OPSMAN_CLIENT_ID}" \
      --client-secret "${OPSMAN_CLIENT_SECRET}" \
      --username "$PCF_OPSMAN_ADMIN" \
      --password "$PCF_OPSMAN_ADMIN_PASSWORD" \
      --skip-ssl-validation \
      curl --silent --path "/api/v0/diagnostic_report"
  )

  stemcell=$(
    echo $diagnostic_report |
    jq \
      --arg version "$STEMCELL_VERSION" \
      --arg glob "$IAAS" \
    '.stemcells[] | select(contains($version) and contains($glob))'
  )

  if [[ -z "$stemcell" ]]; then
    echo "Downloading stemcell $STEMCELL_VERSION"

    product_slug=$(
      jq --raw-output \
        '
        if any(.Dependencies[]; select(.Release.Product.Name | contains("Stemcells for PCF (Windows)"))) then
          "stemcells-windows-server"
        elif any(.Dependencies[]; select(.Release.Product.Name | contains("Stemcells for PCF (Ubuntu Xenial)"))) then
          "stemcells-ubuntu-xenial"
        else
          "stemcells"
        end
        ' < pivnet-product/metadata.json
    )

    pivnet-cli login --api-token="$PIVNET_API_TOKEN"
    pivnet-cli download-product-files -p "$product_slug" -r $STEMCELL_VERSION -g "*${IAAS}*" --accept-eula

    SC_FILE_PATH=`find ./ -name *.tgz`

    if [ ! -f "$SC_FILE_PATH" ]; then
      echo "Stemcell file not found!"
      exit 1
    fi

    om-linux -t https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
      --client-id "${OPSMAN_CLIENT_ID}" \
      --client-secret "${OPSMAN_CLIENT_SECRET}" \
      -u "$PCF_OPSMAN_ADMIN" \
      -p "$PCF_OPSMAN_ADMIN_PASSWORD" \
      -k \
      upload-stemcell \
      -s $SC_FILE_PATH
  fi
fi

# Should the slug contain more than one product, pick only the first.
FILE_PATH=`find ./pivnet-product -name *.pivotal | sort | head -1`
om-linux -t https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  -u "$PCF_OPSMAN_ADMIN" \
  -p "$PCF_OPSMAN_ADMIN_PASSWORD" \
  -k \
  --request-timeout 3600 \
  upload-product \
  -p $FILE_PATH
