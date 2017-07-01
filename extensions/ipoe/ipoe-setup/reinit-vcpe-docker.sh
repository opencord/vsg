#!/bin/bash
#**************************************************************/
#** File:         reinit-vcpe-docker.sh                       */
#** Contents:     Contains shell script to reinit vcpe docker */
#**               to revert back to default IPv4              */
#**               mode of operation.                          */
#**************************************************************/
#
# This script should be invoked when IPv6 mode is disabled
# through REST API 
#
time_begin=`date`
echo "vsg_vcpe_proxy_setup.sh: Begin"
echo "Script execution begins: $time_begin"

if ! [ $# -eq 1 ]; 
then
   echo "Missing Argument error..."
   echo "Usage: $0 <docker name> "
   exit 0
else
   TARGET_DOCKER_NAME=$1
   TARGET_DOCKER_NAME=`echo $TARGET_DOCKER_NAME| tr '[:upper:]' '[:lower:]'`
   export TARGET_DOCKER_NAME
   WIDE_DHCP6_VARS="wide-dhcp6.vars"
fi
if [ -z "$IPOE_SETUP_DIR" ]; then
  echo "Warning...IPOE_SETUP_DIR is not setup. Source from default location.."
  if [ -f /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS ]; then
    source /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS
  else
    source /cord/ipoe-setup/$WIDE_DHCP6_VARS
  fi

  if [ "$CORD_ENV" == "true" ]; then
      IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  else
      IPOE_SETUP_DIR=/cord/ipoe-setup
  fi
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi
cd $IPOE_SETUP_DIR
source $WIDE_DHCP6_VARS


echo "Restoring dnsmasq and restarting the docker instance.."
if [ "$CORD_ENV" == "true" ]; then
  echo "Stopping dnsmasq...ignore the message--- No such file or directory."
  docker exec -i $TARGET_DOCKER_NAME cp /etc/service/dnsmasq-safe/run.save /etc/service/dnsmasq-safe/run
  docker exec -i $TARGET_DOCKER_NAME cp /etc/service/dnsmasq/run.save /etc/service/dnsmasq/run
  echo "restarting the docker instance $TARGET_DOCKER_NAME"
  docker restart $TARGET_DOCKER_NAME 
  docker exec -i $TARGET_DOCKER_NAME ps -fade|grep dnsmasq
  docker exec -i $TARGET_DOCKER_NAME rm /var/lib/dhcpv6/client.lease
#
# TODO: Check the return value to make sure that dnsmasq is running.
#
else
  echo "restarting the docker instance $TARGET_DOCKER_NAME"
  docker restart $TARGET_DOCKER_NAME 
  docker exec -i $TARGET_DOCKER_NAME ps -fade|grep dnsmasq
  docker exec -i $TARGET_DOCKER_NAME rm /var/lib/dhcpv6/client.lease
fi

time_end=`date`
echo "Begin $time_begin" > $vsg_home_dir/$TARGET_DOCKER_NAME
echo $TARGET_DOCKER_NAME >> $vsg_home_dir/$TARGET_DOCKER_NAME
echo "End $time_end" >> $vsg_home_dir/$TARGET_DOCKER_NAME
echo "reinit-vcpe-docker.sh execution completed successfully: $time_end"


