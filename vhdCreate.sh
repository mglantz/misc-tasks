#!/bin/bash
# Magnus Glantz, sudo@redhat.com, 2017
# Upload custom Azure VM image

# Resource group name
GROUP=$1
# VM image file name
FILE=$2
# VM name on Azure
IMAGENAME=$3

# Valid values:
# centralus,eastasia,southeastasia,eastus,eastus2,westus,westus2,northcentralus,southcentralus
# westcentralus,northeurope,westeurope,japaneast,japanwest,brazilsouth,australiasoutheast,australiaeast
# westindia,southindia,centralindia,canadacentral,canadaeast,uksouth,ukwest,koreacentral,koreasouth
LOCATION=northeurope

# Create Azure Resource Group
azure group create $GROUP $LOCATION

# Create Storage account
azure storage account create --sku-name LRS --kind BlobStorage --access-tier Hot -l $LOCATION -g $GROUP ${GROUP}storageaccount

# Fetch account key
azure storage account keys list -g $GROUP ${GROUP}storageaccount >$GROUP.keys

ACCOUNT="${GROUP}storageaccount"
KEY=$(grep key1 $GROUP.keys|awk '{ print $3 }')

# Create storage container
azure storage container create -p Off -a $ACCOUNT -k $KEY --container vms

# Upload VHD image to blob
azure storage blob upload -t block -b $IMAGENAME -a $ACCOUNT -k $KEY --container $IMAGENAME -f $FILE
