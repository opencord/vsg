
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
#** File:         vsg_vcpe_proxy_setup.sh                   */
#** Contents:     Contains shell script to setup packages & */
#**               applications inside the VCPE.             */
#************************************************************/

time_begin=`date`
echo $time_begin
echo "vsg_vcpe_proxy_setup.sh: Begin"

function extract_stag_ctag() {
   echo "Entering extract_stag_ctag function.."
   VCPE_NAME=$VCPEPROXY_NAME
   echo "Input String $VCPE_NAME"
   vcpe_substrings=$( echo $VCPE_NAME | tr "-" "\n" )
   i=0
   for str in $vcpe_substrings
   do
       echo "i=$i str=$str"
       if [ $i -eq 1 ]; then
          stag=$str
       fi
       if [ $i -eq 2 ]; then
          ctag=$str
       fi
       i=$(( i + 1 ))
    done

   echo "Parsed String output: stag=$stag ctag=$ctag "
   STAG=$stag; export STAG
   CTAG=$ctag; export CTAG
}

function install_restserver() {
    echo "install_rest(): Installing REST artifacts in docker instance: $VCPEPROXY_NAME"
    time sudo docker exec -t $VCPEPROXY_NAME apt-get update
    echo "Installing npm.."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install npm -y
    echo "Installing json-server.."
    time sudo docker exec -t $VCPEPROXY_NAME npm install -g json-server@0.9.6
    echo "Installing line-reader.."
    time sudo docker exec -t $VCPEPROXY_NAME npm install -g line-reader
    echo "Installing bluebird.."
    time sudo docker exec -t $VCPEPROXY_NAME npm install -g bluebird
#PPPoE http server
    echo "Installing express.."
    time sudo docker exec -t $VCPEPROXY_NAME npm install -g express
    echo "Installing body-parser.."
    time sudo docker exec -t $VCPEPROXY_NAME npm install -g body-parser
#PPPoE http server end
}

function install_pppoe_soft() {
    echo "install_pppoe_soft(): Installing PPPoE software in $VCPEPROXY_NAME"
    time sudo docker exec -t $VCPEPROXY_NAME apt-get update
    echo "Installing ppp.."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install ppp -y
    echo "Installing pppoe.."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install pppoe -y
}

function install_ipv6_soft() {
    echo "install_pppoe_soft(): Installing IPv6 software in $VCPEPROXY_NAME"
    time sudo docker exec -t $VCPEPROXY_NAME apt-get update
    echo "Installing DHCPv6.."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install radvd -y
}

function install_network_soft() {
    echo "install_soft(): Installing required software in $VCPEPROXY_NAME"
    time sudo docker exec -t $VCPEPROXY_NAME apt-get update
    echo "Installing iptables.."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install iptables -y
    echo "Installing tcpdump..."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install tcpdump -y
    echo "installing Node Js.."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install nodejs -y
    echo "installing...sshpass.."
    time sudo docker exec -t $VCPEPROXY_NAME apt-get install sshpass -y
}

function get_vcpeproxy_wan_ip() {
  echo "Entering get_vcpeproxy_wan_ip function.."
  addr=`sudo docker exec -t $VCPEPROXY_NAME ifconfig $VCPEPROXY_WAN_IFACE|grep "inet addr"| awk '{ print $2 }'`

  addr=`echo $addr|tr ":" "\n"`
  i=1
  for str in $addr
  do
      echo "i=$i str=$str"
      if [ $i -eq 2 ]; then
        VCPEPROXY_WAN_IP=$str; export VCPEPROXY_WAN_IP
      fi
      i=$(( i + 1 ))
  done
  echo "Returning $VCPEPROXY_WAN_IP"
}

function install_and_spinup_apmgmt() {
 if [ -z $VCPEPROXY_DOCKER_HOME ]; then
    echo "cleaning up $VCPEPROXY_DOCKER_HOME directory"
    sudo -E docker exec -t $VCPEPROXY_NAME rm -rf  $VCPEPROXY_DOCKER_HOME
  fi
  sudo -E docker exec -t $VCPEPROXY_NAME mkdir -p $VCPEPROXY_DOCKER_HOME
  sudo docker cp $vsg_home_dir/$vsg_env_file $VCPEPROXY_NAME:$VCPEPROXY_DOCKER_HOME
  echo "VCPEPROXY_WAN_IP=$VCPEPROXY_WAN_IP"

  # VLAN information
  echo "{\"s-vlan\":\"$STAG\",\"c-vlan\":\"$CTAG\"}" > $vsg_home_dir/$PPPOE_AP_MGMT_DIR/info.txt
  # Information on device for ONOS network configuration
  echo "curl -X POST http://$NETCFG_CONSOLIDATOR_IP:$NETCFG_RESTAPI_PORT/rest:$VCPEPROXY_WAN_IP:$AP_RESTAPI_PORT" > $vsg_home_dir/$PPPOE_AP_MGMT_DIR/$AP_REST_NETCFG
  chmod +x $vsg_home_dir/$PPPOE_AP_MGMT_DIR/$AP_REST_NETCFG

  echo "Archiving it to $APMGMT_TAR_FILE"
  cd $vsg_home_dir/$PPPOE_AP_MGMT_DIR; tar -cvf - . >$APMGMT_TAR_FILE
  sudo docker cp $APMGMT_TAR_FILE $VCPEPROXY_NAME:$NODEJS_MODULES_DIR
  echo "Archiving it to $IPV6_TAR_FILE"
  cd $vsg_home_dir/$IPV6_AP_DIR; tar -cvf - . >$IPV6_TAR_FILE
  sudo docker cp $IPV6_TAR_FILE $VCPEPROXY_NAME:$VCPEPROXY_DOCKER_HOME
  sudo docker cp $vsg_home_dir/$proxy_ap_mgmt_start_script $VCPEPROXY_NAME:$VCPEPROXY_DOCKER_HOME
  sudo docker cp $vsg_home_dir/$proxy_ap_mgmt_stop_script $VCPEPROXY_NAME:$VCPEPROXY_DOCKER_HOME
  sudo docker cp $vsg_home_dir/$proxy_ipv6_setup $VCPEPROXY_NAME:$VCPEPROXY_DOCKER_HOME
  sudo docker exec $VCPEPROXY_NAME chmod +x $VCPEPROXY_DOCKER_HOME/$proxy_ap_mgmt_start_script
  sudo docker exec $VCPEPROXY_NAME chmod +x $VCPEPROXY_DOCKER_HOME/$proxy_ap_mgmt_stop_script
  sudo docker exec $VCPEPROXY_NAME chmod +x $VCPEPROXY_DOCKER_HOME/$proxy_ipv6_setup
  if [[ "x$VSG_DOCKER_IPV4" != "xipv4" ]]; then
    echo "Setup and start IPv6 apps"
    sudo docker exec $VCPEPROXY_NAME $VCPEPROXY_DOCKER_HOME/$proxy_ipv6_setup
  fi

  echo "mv json-server:/usr/local/lib/node_modules/json-server/lib/server/public"
  sudo docker exec $VCPEPROXY_NAME mv /usr/local/lib/node_modules/json-server/lib/server/public/index.html /usr/local/lib/node_modules/json-server/lib/server/public/index.html_sav

  echo "Starting proxy_ap_mgmt_start_script"
  sudo docker exec $VCPEPROXY_NAME $VCPEPROXY_DOCKER_HOME/$proxy_ap_mgmt_start_script $VSG_DOCKER_IPV4
  echo "Started proxy_ap_mgmt_start_script"
  echo "check whether nodejs is running"
  sudo docker exec $VCPEPROXY_NAME ps -fade|grep nodejs
}

function send_device_info_to_consolidator () {
    sudo docker exec $VCPEPROXY_NAME ps -fade|grep nodejs|grep cController > /dev/null 2>&1
    if [ "$?" == 0 ]; then
        echo "Posting rest:$VCPEPROXY_WAN_IP:$AP_RESTAPI_PORT to consolidator..."
        sudo docker exec $VCPEPROXY_NAME bash $NODEJS_MODULES_DIR$AP_REST_NETCFG
    fi
}

VCPEPROXY_NAME=$1; export VCPEPROXY_NAME
VSG_ID=$2; export VSG_ID
VCPE_PROXY_ID=$3; export VCPE_PROXY_ID 

if [ -z $VCPEPROXY_NAME ]; then
  echo " Missing Argument: VCPEPROXY_NAME...."
  exit 1
fi
if [ -z $VSG_ID ]; then
  echo " Missing Argument: VSG_ID...."
  exit 1
fi
if [ -z $VCPE_PROXY_ID ]; then
  echo " Missing Argument: VCPE_PROXY_ID...."
  exit 1
fi
echo "Reinitializing $VCPEPROXY_NAME docker as vcpe proxy"
extract_stag_ctag 
sudo -E $vsg_home_dir/$respin_vcpeproxy_docker_script

# Check whethere necessary packages are installed in VCPE
sudo docker exec $VCPEPROXY_NAME which nodejs > /dev/null 2>&1
if [ "$?" == 1 ]; then
    # VCPE docker image may be from repository, then install necessary packages
    echo "Continuing the installation of vcpe_proxy docker"
    install_network_soft
    echo "Installing rest servcer"
    install_restserver
    echo "Installing pppoe soft"
    install_pppoe_soft
    echo "Installing ipv6 soft"
    install_ipv6_soft
fi
echo "Extracting vcpeproxy_wan_ip"
get_vcpeproxy_wan_ip
echo "Before AP mgmt spinup...VCEPROXY_WAN_IP=$VCPEPROXY_WAN_IP"
install_and_spinup_apmgmt
echo "Before sending device info to consolidator..."
send_device_info_to_consolidator

# To indicate VCPE setup completion
time_end=`date`
echo "Begin $time_begin" > $vsg_home_dir/$VCPEPROXY_NAME
echo $VCPEPROXY_NAME >> $vsg_home_dir/$VCPEPROXY_NAME
echo "End $time_end" >> $vsg_home_dir/$VCPEPROXY_NAME
echo $time_end
echo "vsg_vcpe_proxy_setup.sh: End"
