#!/bin/sh
#************************************************************/
#** File:         update-cord-files.sh                      */
#** Contents:     Contains shell script to update cord-4.0  */
#**               installation files.                       */
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
#source $IPOE_SETUP_DIR/wide-dhcp6.vars

CORD_ROOT=/home/ubuntu/cord
CORD_BUILD=/home/ubuntu/cord/build
IPOE_ROOT=/home/ubuntu/ipoe/ipoe-setup

if [ ! -f $IPOE_ROOT/cord-scenario-Vagrantfile ]; then
  echo "Missing $IPOE_ROOT/cord-scenario-Vagrant file"
  exit 1
fi

if [ ! -f $IPOE_ROOT/cord-scenario-config.yml ]; then
  echo "Missing $IPOE_ROOT/cord-scenario-Vagrantfile"
  exit 1
fi

if [ ! -f $IPOE_ROOT/onoscord-defaults.yml ]; then
  echo "Missing $IPOE_ROOT/onoscord-defaults.yml file"
  exit 1
fi
if [ ! -f $IPOE_ROOT/pull-docker-image-main.yml ]; then
  echo "Missing $IPOE_ROOT/onoscord-defaults.yml file"
  exit 1
fi
if [ ! -f $IPOE_ROOT/vsg.xproto ]; then
  echo "Missing $IPOE_ROOT/vsg.xproto"
  exit 1
fi

if [ ! -f $CORD_BUILD/scenarios/cord/Vagrantfile.bkp ]; then
  echo "Copying cord-scenario-Vagrantfile"
  cp $CORD_BUILD/scenarios/cord/Vagrantfile $CORD_BUILD/scenarios/cord/Vagrantfile.bkp
  cp $IPOE_ROOT/cord-scenario-Vagrantfile $CORD_BUILD/scenarios/cord/Vagrantfile
fi

if [ ! -f $CORD_BUILD/scenarios/cord/config.yml.bkp ]; then
  echo "Copying cord-scenario-config.yml"
  cp $CORD_BUILD/scenarios/cord/config.yml $CORD_BUILD/scenarios/cord/config.yml.bkp
  cp $IPOE_ROOT/cord-scenario-config.yml $CORD_BUILD/scenarios/cord/config.yml
fi

if [ ! -f $CORD_BUILD/platform-install/roles/onos-cord-install/defaults/main.yml.bkp ]; then
  echo "Copying onos-cord-defaults file to use voltha-onos"
  cp $CORD_BUILD/platform-install/roles/onos-cord-install/defaults/main.yml $CORD_BUILD/platform-install/roles/onos-cord-install/defaults/main.yml.bkp
  cp $IPOE_ROOT/onoscord-defaults.yml $CORD_BUILD/platform-install/roles/onos-cord-install/defaults/main.yml
fi

if [ ! -f $CORD_BUILD/platform-install/roles/pull-xos-docker-images/tasks/main.yml.bkp ]; then
  echo "Copying xos-docker-images yml file"
  cp $CORD_BUILD/platform-install/roles/pull-xos-docker-images/tasks/main.yml $CORD_BUILD/platform-install/roles/pull-xos-docker-images/tasks/main.yml.bkp
  cp $IPOE_ROOT/pull-docker-image-main.yml $CORD_BUILD/platform-install/roles/pull-xos-docker-images/tasks/main.yml
fi

#if [ ! -f $CORD_ROOT/orchestration/xos/containers/xos/BUILD/opt/xos/services/vsg/vsg.xproto.bkp ]; then
#  echo "Copying vsg docker-xproto file"
#  cp $CORD_ROOT/orchestration/xos/containers/xos/BUILD/opt/xos/services/vsg/vsg.xproto $CORD_ROOT/orchestration/xos/containers/xos/BUILD/opt/xos/services/vsg/vsg.xproto.bkp
#  cp $IPOE_ROOT/vsg.xproto $CORD_BUILD/orchestration/xos/containers/xos/BUILD/opt/xos/services/vsg/vsg.xproto
#fi

if [ ! -f $CORD_ROOT/orchestration/xos_services/vsg/xos/vsg.xproto.bkp ]; then
  echo "Copying vsg docker-xproto file into xos_services"
  cp $CORD_ROOT/orchestration/xos_services/vsg/xos/vsg.xproto $CORD_ROOT/orchestration/xos_services/vsg/xos/vsg.xproto.bkp
  cp $IPOE_ROOT/vsg.xproto $CORD_ROOT/orchestration/xos_services/vsg/xos/vsg.xproto
fi

echo "Cord file updates completed...."
time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
