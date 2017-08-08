
# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#!/usr/bin/env bash
#************************************************************/
#** File:         vsg_vcpe_gwbr_setup.sh                    */
#** Contents:     Contains shell script to setup vcpe_gwbr  */
#**               in VSG to allow traffic to flow between   */
#**               VCPE, VSG and nova-compute nodes.         */ 
#************************************************************/

date
echo "vsg_vcpe_gwbr_setup.sh: Begin"

function setup_vcpe_gwbr_in_vsg() {
  if brctl show $VCPEGW_BR_NAME ; then
    echo "$VCPEGW_BR_NAME already exists...delete and recreate it again"
    sudo -E ip link set dev $VCPEGW_BR_NAME down
    sleep 1
    sudo -E brctl delbr $VCPEGW_BR_NAME
  fi

  sleep 1
  sudo -E brctl addbr $VCPEGW_BR_NAME
  sleep 1
  sudo -E ip link set dev $VCPEGW_BR_NAME dynamic off
  sleep 1
  sudo -E ip link set dev $VCPEGW_BR_NAME up
  echo "Setting vcpe_gwbr IP in VSG ($vsg_id) as $vcpe_gwbr_ip"
  sudo -E ip addr add $vcpe_gwbr_ip/$VCPEGW_NETMASK_BITS dev $VCPEGW_BR_NAME 
  ifconfig $VCPEGW_BR_NAME
  sudo -E brctl addif $VCPEGW_BR_NAME $NETCFG_UP_IFACE
  echo "$VCPEGW_BR_NAME successfully setup.."
}
#
# Setup the NAT rules to allow VCPE GW instances to
# access the internet. The vcpe docker instances created
# by XOS go directly through br-wan. So, there is no need
# to setup any NAT rules. In the case of VCPE GW instance,
# the traffic will go through vcpe_gwbr and get NAT'd and
# sent through br-wan. So, we need to setup the NAT rules
# in VSG to make this work.
#

function setup_dnat_for_vcpegw_traffic() {

    sudo /sbin/iptables -t nat -A POSTROUTING -s $VCPEGW_BR_SUBNET/$VCPEGW_NETMASK_BITS -o $VSG_WAN_BR_NAME -j MASQUERADE
    sudo /sbin/iptables -A FORWARD -i $VCPEGW_BR_NAME -o $VSG_WAN_BR_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo /sbin/iptables -A FORWARD -i $VSG_WAN_BR_NAME -o $VCPEGW_BR_NAME -j ACCEPT
} 

if [ -z $HOME_DIR ]; then
   HOME_DIR=`pwd`
   echo "WARNING>>>>HOME_DIR was not setup properly...!!!"
   echo "Using $HOME_DIR as the home directory"
fi

setup_vcpe_gwbr_in_vsg
setup_dnat_for_vcpegw_traffic
date
echo "vsg_vcpe_gwbr_setup.sh: End"

