#!/bin/bash
# Magnus Glantz, sudo@redhat.com, 2017
# Simple script which provisiones a virtualbox VM via a simple Satellite 6 ssh hook.
# Just do 'new host' then set the MAC address on the first nic and click create..

(
VM=$1
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
HOME=/Users/mglantz
PATH="/opt/local/bin:/opt/local/sbin:$PATH"
SATELLITEFQDN="sat6.mglantznet.com"
SATELLITEUSER="admin"
SATELLITEPASS="redhat123"

VBoxManage=/usr/local/bin/VBoxManage

cd $HOME

echo "First argument: $1"

$VBoxManage createhd --filename $VM.vdi --size 32768
$VBoxManage createvm --name $VM --ostype RedHat_64 --register
$VBoxManage storagectl $VM --name "SATA" --add sata --controller IntelAHCI
$VBoxManage storageattach $VM --storagectl "SATA" --port 0 --device 0 --type hdd --medium $VM.vdi
$VBoxManage storagectl $VM --name "IDE" --add ide
ssh root@$SATELLITEFQDN "/usr/sbin/foreman-rake bootdisk:generate:full_host NAME=$VM OUTPUT=/tmp/$VM.iso"
CONTINUE=1
while [ $CONTINUE -eq 1 ]; do
        echo "Fetching bootiso"
        scp root@$SATELLITEFQDN:/tmp/$VM.iso $HOME/Downloads/
        if [ -f $HOME/Downloads/$VM.iso ]; then
                CONTINUE=0
        else
                sleep 1
        fi
done

$VBoxManage storageattach $VM --storagectl IDE --port 0 --device 0 --type dvddrive --medium $HOME/Downloads/$1.iso
$VBoxManage modifyvm $VM --ioapic on
$VBoxManage modifyvm $VM --boot1 dvd --boot2 disk --boot3 none --boot4 none
$VBoxManage modifyvm $VM --memory 2048 --vram 128
sleep 1
$VBoxManage modifyvm $VM --nic1 hostonly --hostonlyadapter1 vboxnet0
MACADDR=$(curl -k -u $SATELLITEUSER:$SATELLITEPASS -X GET -H "Accept: application/json" -H "Content-Type: application/json" https://$SATELLITEFQDN/api/hosts/$VM 2>/dev/null|cut -d',' -f5|cut -d'"' -f4|sed 's/://g')

echo "MACADDR:$MACADDR"

$VBoxManage modifyvm $VM --macaddress1 $MACADDR
sleep 1
$VBoxManage startvm $VM

) >./$VM.log 2>&1
