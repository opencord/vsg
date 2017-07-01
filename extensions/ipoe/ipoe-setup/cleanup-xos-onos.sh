#!/bin/bash
#************************************************************/
#** File:         cleanup-xos-onos.sh                       */
#** Contents:     Contains shell script to cleanup          */
#**               XOS and ONOS                              */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

if [ -z "$IPOE_SETUP_DIR" ]; then
  IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi

echo "Cleanup and rebuild XOS, ONOS and OpenStack..."
cd ~/cord/build
echo "<<<<<<<<Tearing down XOS>>>>>>>>>>"
make xos-teardown
sleep 1
echo "<<<<<<<<Cleaning up OpenStack>>>>>>>>"
make clean-openstack
sleep 1
echo "<<<<<<<<<Cleaning up Onos>>>>>>>>>"
make clean-onos
sleep 1 
echo "<<<<<<<< Rebuild XOS-ONOS-OpenStack>>>>>>"
make -j4 build
echo "<<<<<<<<Refresh Compute_node>>>>>"
make compute-node-refresh
sleep 1
echo "<<<<<<<<Rebuild VSG and pod-test VMs>>>>>"
make pod-test
echo "<<<<<<<<Cleanup is complete>>>>>>"

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
