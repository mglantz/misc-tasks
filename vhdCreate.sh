#!/bin/bash
# Magnus Glantz, sudo@redhat.com, 2017
# Upload custom Azure VM image

# Resource group name
GROUP=$1
# VM image file name
FILE=$2
# Storage account name
ACCOUNT=$3
# VM name on Azure. Should be xyz.vhd
IMAGENAME=$4

# Valid values:
# centralus,eastasia,southeastasia,eastus,eastus2,westus,westus2,northcentralus,southcentralus
# westcentralus,northeurope,westeurope,japaneast,japanwest,brazilsouth,australiasoutheast,australiaeast
# westindia,southindia,centralindia,canadacentral,canadaeast,uksouth,ukwest,koreacentral,koreasouth
LOCATION=northeurope

# Create a resource group
az group create -n $GROUP -l northeurope

# Create the storage account to upload the vhd
az storage account create -g $GROUP -n $ACCOUNT -l northeurope --sku PREMIUM_LRS

# Get a storage key for the storage account
STORAGE_KEY=$(az storage account keys list -g $GROUP -n $ACCOUNT --query "[?keyName=='key1'] | [0].value" -o tsv)

# Create the container for the vhd
az storage container create -n vhds --account-name $ACCOUNT --account-key ${STORAGE_KEY}

# Upload the vhd to a blob
az storage blob upload -c vhds -f $FILE -n $IMAGENAME --account-name $ACCOUNT --account-key ${STORAGE_KEY}

read -p "Try to deploy VM from image? (y/n)" ANSWER

if echo $ANSWER|grep -i "y" >/dev/null; then
  az disk create --resource-group $GROUP --name myManagedDisk --source https://$ACCOUNT.blob.core.windows.net/vhds/$IMAGENAME.vhd
  az vm create -g $GROUP -l northeurope -n custom-vm --attach-os-disk myManagedDisk --os-type linux --admin-username deploy --generate-ssh-keys
  az vm user update --resource-group $GROUP -n custom-vm -u deploy --ssh-key-value "$(< ~/.ssh/id_rsa.pub)"
  IP_ADDRESS=$(az vm list-ip-addresses -g $GROUP -n custom-vm --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)
  echo "You can now connect using 'ssh deploy@${IP_ADDRESS}'"
else
  echo "Done. Blob URL is: https://$ACCOUNT.blob.core.windows.net/vhds/$IMAGENAME.vhd"
fi
