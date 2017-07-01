#!/bin/bash
#************************************************************/
#** File:         cleanup-ipoe                              */
#** Contents:     Contains shell script to cleanup a IPOE   */
#**               VM and onusim-server VM.                  */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

if [ -z "$IPOE_SETUP_DIR" ]; then
  IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi

echo "Execution of this script will completely destroy IPOE VM environment"
read -p "Do you want to continue? Enter Yes or No : " resp
resp_nocase=`echo $resp|tr "[:upper:]" "[:lower:]"`
echo "Translated input $resp_nocase"
if [ "$resp_nocase" != "yes" ]; then
    echo "IPoE server environment not cleanedup...."
    exit 0
fi

ipoe_server=`sudo virsh list --all|grep ipoe-server`
if [ ! -z "$ipoe_server" ]; then
   echo "Cleaning up ipoe-server VM"
   sudo virsh destroy ipoe-server
   sleep 1
   sudo virsh undefine ipoe-server
   sleep 1
   sudo virsh net-destroy ipoe-network
   sudo virsh net-destroy nni-network
fi  
sleep 1
echo "Cleaning up onusim-server VMs..."

onusim_vms_list=`sudo virsh list --all|grep onusim-server |awk '{ print $2 }'`
echo "Deleting onusim-vm: $onusim_vms_list"
if [ ! -z "$onusim_vms_list" ]; then
   IFS=' ' read -ra onusim_names <<< $onusim_vms_list
   for vm in "${onusim_names[@]}"
   do
      echo "Deleting VM $vm"
      sudo virsh destroy $vm
      sleep 1
      sudo virsh undefine $vm
   done
fi

num_vms=`sudo virsh list --all|grep "ipoe-server|onusim-server" `
if [ ! -z $num_vms ]; then
   echo " WARNING... Not all VMs are deleted.."
   exit 1
fi

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"

