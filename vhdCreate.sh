#!/bin/bash
# Magnus Glantz, sudo@redhat.com, 2017
# Upload custom Azure VM image or deploy VMs from it

if echo $1|grep -i help >/dev/null; then
	echo "Usage: $0:"
	echo "Attention: storageaccount name have to be lower case."
	echo
	echo "To upload a VM image: $0 upload resourceGroup localVMfile storageaccountname azureVMname.vhd"
	echo "Example: $0 upload myResourceGroup /path/to/custom-vm.vhd mystorageaccount customVm.vhd"
	echo
	echo "To deploy VM image: $0 deploy resourceGroup nameOfVM storageaccountname azureVMname.vhd"
	echo "Example: $0 deploy myResourceGroup myCustomVM1 mystorageaccount customVm.vhd"
fi

# If we're to upload a image or deploy a VM.
# Valid values: upload, deploy
WHAT2DO=$1

# Resource group name
GROUP=$2

# If we'll deploy a VM, name of virtual machine which we'll deploy on Azure
if echo $WHAT2DO|grep -i deploy >/dev/null; then
        VMNAME=$3

# Local VM image file name
elif echo $WHAT2DO|grep -i upload >/dev/null; then
	FILE=$3
fi

# Storage account name
ACCOUNT=$4

# VM name on Azure. Should be xyz.vhd
IMAGENAME=$5

# Valid values:
# centralus,eastasia,southeastasia,eastus,eastus2,westus,westus2,northcentralus,southcentralus
# westcentralus,northeurope,westeurope,japaneast,japanwest,brazilsouth,australiasoutheast,australiaeast
# westindia,southindia,centralindia,canadacentral,canadaeast,uksouth,ukwest,koreacentral,koreasouth
LOCATION=northeurope

if echo $WHAT2DO|grep -i upload >/dev/null; then
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
	
	# Print blob URL
	echo "Done. Blob URL is: https://$ACCOUNT.blob.core.windows.net/vhds/$IMAGENAME.vhd"

elif echo $WHAT2DO|grep -i deploy >/dev/null; then
	az disk create --resource-group $GROUP --name ${VMNAME}ManagedDisk --source https://$ACCOUNT.blob.core.windows.net/vhds/$IMAGENAME
	az vm create -g $GROUP -l $LOCATION -n $VMNAME --attach-os-disk ${VMNAME}ManagedDisk --os-type linux --admin-username deploy --ssh-key-value ~/.ssh/id_rsa.pub
  	IP_ADDRESS=$(az vm list-ip-addresses -g $GROUP -n $VMNAME --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)
	echo "If your image works, you should be able to connect using: ssh deploy@$IP_ADDRESS"
fi
