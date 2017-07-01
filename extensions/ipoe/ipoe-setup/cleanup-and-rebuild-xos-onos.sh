#!/bin/bash
#/************************************************************
#** File:         cleanup-and-rebuild-xos-onos.sh           *
#** Contents:     Contains shell script to clean up running *
#**               XOS, ONOS and OpenStack. Also, ONOS       *
#**               docker image is replaced by voltha-ons    *
#************************************************************/
time_begin=`date`
echo "cleanup-and-rebuild-xos-ons.sh: Begin"
echo "Script execution begins: $time_begin"

uid=`id|grep libvirtd`
if [ -z "$uid" ]; then
 echo "Re-login using su - ubuntu to get into libvirtd group"
 exit 1
fi
sshpass -p ubuntu ssh -o StrictHostKeyChecking=no vagrant@head1 'sudo docker pull opencord/voltha-onos'
if [ $? -eq 0 ]; then
  echo "Pulled voltha-onos docker image"
else
  echo "Eror in pulling voltha-onos docker image..."
  exit 1
fi
sshpass -p ubuntu ssh -o StrictHostKeyChecking=no vagrant@head1 'sudo docker images|grep voltha'

echo "<<<<<<<<<Reinit onos-cord default to use voltha-onos docker images>>>>"
ONOSCORD_DEFAULTS=/home/ubuntu/cord/build/platform-install/roles/onos-cord-install/defaults
ls $ONOSCORD_DEFAULTS
if [ ! -f $ONOSCORD_DEFAULTS/main.yml.bkp ]; then
  echo "Copying updated onos-cord-install defaults file"
  cp $ONOSCORD_DEFAULTS/main.yml $ONOSCORD_DEFAULTS/main.yml.bkp
  if [ ! -f ./onoscord-defaults.yml ]; then
     echo "onos-cord defaults file not found!!!..."
     exit 1
  fi
  cp ./onoscord-defaults.yml $ONOSCORD_DEFAULTS/main.yml
fi
echo "<<<<<<<< Rebuild XOS-ONOS-OpenStack>>>>>>"

   
 
echo "Cleanup and rebuild XOS, ONOS and OpenStack..."
cd /home/ubuntu/cord/build
echo "<<<<<<<<Tearing down XOS>>>>>>>>>>"
make xos-teardown
sleep 1
echo "<<<<<<<<Cleaning up OpenStack>>>>>>>>"
make clean-openstack
sleep 1
echo "<<<<<<<<<Cleaning up Onos>>>>>>>>>"
make clean-onos
sleep 1 
echo "<<<<<<<<<Reinit onos-cord default to use voltha-onos docker images>>>>"
ONOSCORD_DEFAULTS=~/cord/build/platform-install/roles/onos-cord-install/defaults
if [ ! -f $ONOSCORD_DEFAULTS/main.yml.bkp ]; then
  cp $ONOSCORD_DEFAULTS/main.yml $ONOSCORD_DEFAULTS/defaults/main.yml.bkp
fi
cp onoscord-defaults.yml $ONOSCORD_DEFAULTS/main.yml
echo "<<<<<<<< Rebuild XOS-ONOS-OpenStack>>>>>>"
make -j4 build
echo "<<<<<<<<Refresh Compute_node>>>>>"
make compute-node-refresh
sleep 1
echo "<<<<<<<<Rebuild VSG and pod-test VMs>>>>>"
make pod-test
echo "<<<<<<<<Cleanup is complete>>>>>>"
time_end=`date`
echo "Begin $time_begin" 
echo "End $time_end" 
echo "Script execution completed successfully: $time_end"
echo "$0: End"

