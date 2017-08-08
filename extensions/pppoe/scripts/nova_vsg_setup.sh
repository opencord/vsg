
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
#** File:         nova_vsg_setup.sh                         */
#** Contents:     Contains shell script to setup VSG and to */
#**               monitor creation of vcpe docker in VSG    */
#************************************************************/

date
echo "nova_vsg_setup.sh: Begin"

function generate_vsg_mac() {
    # Check if VSG IP exists, if it does not exist, create new Proxy LXC
    if ! grep -q "$vsgIp$vsg_str" "$file_vsg_ip"; then
      # get the last line of previous vSG IP, if exists
      if [ -f "$file_vsg_ip" ]; then
        last_line=$( tail -1 $file_vsg_ip | head -1 )
        value=${last_line#*:}
        var=1

        for arr_val in $value; do
          if [ $var == 1 ]; then
            vsg_eth0=$( printf '%d\n' "0x${arr_val}" )
            vsg_eth0=$((vsg_eth0+1))
          elif [ $var == 2 ]; then
            vsg_eth1=$( printf '%d\n' "0x${arr_val}" )
            vsg_eth1=$((vsg_eth1+1))
          elif [ $var == 3 ]; then
            let "lxc = 0x3e"
          fi
          var=$((var+1))
        done
      else
        let "vsg_eth0 = 0x16"
        let "vsg_eth1 = 0x21"
      fi

      hex_vsg_eth0=$( printf "%02x\n" $vsg_eth0 )
      hex_vsg_eth1=$( printf "%02x\n" $vsg_eth1 )
      hex_lxc=$( printf "%02x\n" $lxc )
   else
     echo "vsgIP already in file"
   fi
}

function vsg_script_transfer() {
    echo "vsg_script_transfer"
    scp -r $PPPOE_APPS_DIR/$PPPOE_AP_MGMT_DIR "ubuntu@$vsgIp:$vsg_home_dir"
    scp -r $PPPOE_APPS_DIR/$IPV6_AP_DIR "ubuntu@$vsgIp:$vsg_home_dir"
    scp $HOME_DIR/$vsg_vcpe_proxy_setup_script "ubuntu@$vsgIp:$vsg_home_dir"
    scp $HOME_DIR/$respin_vcpeproxy_docker_script "ubuntu@$vsgIp:$vsg_home_dir"
    scp $HOME_DIR/$proxy_ap_mgmt_start_script "ubuntu@$vsgIp:$vsg_home_dir"
    scp $HOME_DIR/$proxy_ap_mgmt_stop_script "ubuntu@$vsgIp:$vsg_home_dir"
    scp $HOME_DIR/$proxy_ipv6_setup "ubuntu@$vsgIp:$vsg_home_dir"
}

function setup_vcpe_monitoring() {
    echo "Entering setup_vcpe_monitoring..."

#
#  Install the necessary software in vSG
#  WIll not necessary after creating custom docker image
#  with all the necessary software pre-installed.
#
      vsg_ssh_setup
      # Load PPPoE VCPE docker image to avoid pulling from docker repository
      transfer_gw_scripts_and_docker_files
      install_soft
#
# In CORD-2.0, we will use vcpe docker instance created by XOS.
# So, there is no need to create a separate dpbr0 bridge in VSG
#
     create_vsg_env_file
     scp $HOME_DIR/$vsg_env_file ubuntu@$vsgIp:$vsg_home_dir
}

function create_vsg_env_file() {
 echo "Entering create_vsg_env_file....."
 echo "vsg_home_dir=$vsg_home_dir; export vsg_home_dir" >>$HOME_DIR/$vsg_env_file
#
# Scripts running in VSG and VCP refer to the location of
# artifacts in their environment by using the env. variable $HOME_DIR
# HOME_DIR is same as $vsg_home_dir.
#
 echo "HOME_DIR=$vsg_home_dir; export HOME_DIR" >>$HOME_DIR/$vsg_env_file
 echo "vcpe_monitor_script=$vcpe_monitor_script; export vcpe_monitor_script" >>$HOME_DIR/$vsg_env_file
 echo "vcpe_setup_script=$vcpe_setup_script; export vcpe_setup_script" >>$HOME_DIR/$vsg_env_file
 echo "file_vsg_ip=$file_vsg_ip; export file_vsg_ip" >>$HOME_DIR/$vsg_env_file
 echo "vsg_id=$vsg_id; export vsg_id" >>$HOME_DIR/$vsg_env_file
 echo "file_vcpe_id=$file_vcpe_id; export file_vcpe_id" >>$HOME_DIR/$vsg_env_file
 echo "file_vcpe_names=$file_vcpe_names; export file_vcpe_names" >>$HOME_DIR/$vsg_env_file
 echo "nova_compute_ip=$nova_compute_ip; export nova_compute_ip" >>$HOME_DIR/$vsg_env_file
 echo "br_wan_ip=$br_wan_ip; export br_wan_ip" >>$HOME_DIR/$vsg_env_file
 echo "docker_mount_file=$docker_mount_file; export docker_mount_file" >>$HOME_DIR/$vsg_env_file
 echo "proxy_ap_mgmt_start_script=$proxy_ap_mgmt_start_script; export proxy_ap_mgmt_start_script" >>$HOME_DIR/$vsg_env_file
 echo "proxy_ipv6_setup=$proxy_ipv6_setup; export proxy_ipv6_setup" >>$HOME_DIR/$vsg_env_file
 echo "proxy_ap_mgmt_stop_script=$proxy_ap_mgmt_stop_script; export proxy_ap_mgmt_stop_script" >>$HOME_DIR/$vsg_env_file
 echo "vsg_vcpe_gwbr_setup_script=$vsg_vcpe_gwbr_setup_script; export vsg_vcpe_gwbr_setup_script" >>$HOME_DIR/$vsg_env_file
 echo "vsg_vcpe_proxy_setup_script=$vsg_vcpe_proxy_setup_script; export vsg_vcpe_proxy_setup_script" >>$HOME_DIR/$vsg_env_file
 echo "respin_vcpeproxy_docker_script=$respin_vcpeproxy_docker_script; export respin_vcpeproxy_docker_script" >>$HOME_DIR/$vsg_env_file
 echo "vcpe_gwbr_ip=$vcpe_gwbr_ip; export vcpe_gwbr_ip" >>$HOME_DIR/$vsg_env_file
 echo "CONTAINER_VOLUMES=$CONTAINER_VOLUMES; export CONTAINER_VOLUMES" >>$HOME_DIR/$vsg_env_file
 echo "DOCKER_SPINUP_DIR=$DOCKER_SPINUP_DIR; export DOCKER_SPINUP_DIR" >>$HOME_DIR/$vsg_env_file
 echo "vsg_env_file=$vsg_env_file; export vsg_env_file" >>$HOME_DIR/$vsg_env_file
 echo "pppoe_vcpe_image_tar=$pppoe_vcpe_image_tar; export pppoe_vcpe_image_tar" >>$HOME_DIR/$vsg_env_file
}

function install_soft() {
    echo "Installing required VSG software"
    time ssh ubuntu@$vsgIp "sudo apt-get update"
    echo "Installing iptables.."
    time ssh ubuntu@$vsgIp "sudo apt-get install iptables -y"
    echo "Installing tcpdump..."
    time ssh ubuntu@$vsgIp "sudo apt-get install tcpdump -y"
    echo "installing Node Js.."
    time ssh ubuntu@$vsgIp "sudo apt-get install nodejs -y"
    echo "installing...sshpass.."
    time ssh ubuntu@$vsgIp "sudo apt-get install sshpass -y"
}

function setup_vcpegw_bridge_in_vsg() {
    echo "Transfer and setup vcpegw bridge VSG Instance"
    scp $HOME_DIR/$vsg_vcpe_gwbr_setup_script "ubuntu@$vsgIp:$vsg_home_dir"
    sleep 2 
#
# Environment variables file $vsg_env_file should have been transferred
# out to the VSG instance in setup_vsg function.
#
    ssh ubuntu@$vsgIp "source $vsg_home_dir/$vsg_env_file;$vsg_home_dir/$vsg_vcpe_gwbr_setup_script" 
    sleep 2
}

function start_vcpe_monitoring() {
    echo "Transfer VCPE monitoring and setup script to VSG Instance"
    scp $HOME_DIR/$vcpe_monitor_script "ubuntu@$vsgIp:$vsg_home_dir"
    scp $HOME_DIR/$vcpe_setup_script "ubuntu@$vsgIp:$vsg_home_dir"
    touch $HOME_DIR/$file_vcpe_names
    scp $HOME_DIR/$file_vcpe_names "ubuntu@$vsgIp:$vsg_home_dir"
       
    sleep 1
#
# Environment variables file $vsg_env_file should have been transferred
# out to the VSG instance in setup_vsg function.
#
    ssh ubuntu@$vsgIp "source $vsg_home_dir/$vsg_env_file;$vsg_home_dir/$vcpe_monitor_script > $vsg_home_dir/vcpe_monitor.log 2>&1 &"
    sleep 2 
}

function transfer_gw_scripts_and_docker_files() {
    echo "Transferring GW script and docker files to VSG Instance"
    scp $HOME_DIR/$file_vsg_ip "ubuntu@$vsgIp:$vsg_home_dir"
    scp $HOME_DIR/$docker_mount_file "ubuntu@$vsgIp:$vsg_home_dir"
    ssh ubuntu@$vsgIp "cd $vsg_home_dir;tar -xvf $docker_mount_file"

    if [ -f $HOME_DIR/$pppoe_vcpe_image_tar ]; then
        scp $HOME_DIR/$pppoe_vcpe_image_tar "ubuntu@$vsgIp:$vsg_home_dir"

        # Load PPPoE VCPE docker image into docker repository
        ssh ubuntu@$vsgIp "cd $vsg_home_dir; sudo docker load -i ./$pppoe_vcpe_image_tar"
    fi
    sleep 5 
}

function vsg_ssh_setup() {
    echo "Setting up ssh in VSG"
    ssh ubuntu@$vsgIp "mkdir /home/ubuntu/.ssh"
    scp /home/ubuntu/.ssh/config "ubuntu@$vsgIp:/home/ubuntu/.ssh/"
    scp /home/ubuntu/.ssh/id_rsa "ubuntu@$vsgIp:/home/ubuntu/.ssh/"
    ssh ubuntu@$vsgIp "sudo sed -i '1 a $nova_compute_ip nova-compute-1 nova-compute-1' /etc/hosts"
}

#
# Connect VcpeGW bridge to VSG 
#
function connect_vcpegw_bridge_to_vsg() {
  echo "Executing connect_vcpegw_bridge_to_vsg..."
  source ${HOME_DIR}/admin-openrc.sh
  uuid=`nova list --all-tenants|grep $vsgIp|awk '{print $2}'`
  if [ -z $uuid ]; then
     echo "Cannot find $vsgIp in nova list"
     return 1
  fi
  inst_name=`sudo virsh domname $uuid`
  inst_id=`sudo virsh list |grep $inst_name|awk '{print $1}'`
  echo "uuid=$uuid inst_name=$inst_name inst_id=$inst_id" 
  sudo virsh attach-interface $inst_id bridge $VSGGW_BR_NAME
#
# NOTE: To remove attached interface, use the following command.
#  sudo virsh detach-interface $inst-name bridge <Mac-address of eth2 in VSG>
#
# Check whether the interface eth2 ($NETCFG_UP_IFACE)
# is created inside the VSG instance
  ssh ubuntu@$vsgIp "ifconfig $NETCFG_UP_IFACE"
  ssh ubuntu@$vsgIp "sudo ip link set dev $NETCFG_UP_IFACE up"
} 

if [ -z "$1" ]
  then
    echo "VSG Ip Required"
    echo "Usage: nova_vsg_setup.sh <VSG IP> <VSG_ID>"
    exit 1
fi

if [ -z "$2" ]; then
   echo "VSG ID is required.."
    echo "Usage: nova_vsg_setup.sh <VSG IP> <VSG_ID>"
    exit 1
fi

if [ -z $HOME_DIR ]; then
   HOME_DIR=`pwd`
   echo "Missing HOME_DIR setting. Using current dir as HOME: $HOME" 
fi

if [ -z $VCPEGW_BR_NAME ]; then
   echo "VCPEGW_BR_NAME is not configured"
   echo "$0 Script executed terminated.."
   exit 1
fi

if [ -z $VCPEGW_DOCKER_IMAGE ]; then
   echo "VCPE Gateway Docker Image is not configured"
   echo "$0 Script executed terminated.."
   exit 1
fi

vsgIp=$1; export vsgIp
vsg_id=$2; export vsg_id
VSG_ID=$vsg_id;export VSG_ID
vsg_str="_vsg"
value=0
vsg_value=0
post_file=".conf"
dnsmasq_file="/etc/dnsmasq.conf"
vsg_home_dir=/home/ubuntu; export vsg_home_dir
vcpe_monitor_script=vsg_vcpe_monitor.sh
vcpe_setup_script=vsg_vcpe_gwbr_setup.sh
proxy_ap_mgmt_start_script=vcpe_proxy_ap_mgmt_start.sh
proxy_ap_mgmt_stop_script=vcpe_proxy_ap_mgmt_stop.sh
proxy_ipv6_setup=vcpe_proxy_ipv6_setup.sh
file_vsg_ip=vsg_ip_list.txt
file_vcpe_id=vcpe_id_list.txt
file_vcpe_names=vcpe_names_list.txt
vsg_env_file=$VSG_ENV_FILE
vsg_vcpe_gwbr_setup_script=vsg_vcpe_gwbr_setup.sh
vsg_vcpe_proxy_setup_script=vsg_vcpe_proxy_setup.sh
docker_mount_file=docker_mounts.tar
respin_vcpeproxy_docker_script=vsg_respin_vcpeproxy_docker.sh
pppoe_vcpe_image_tar=$PPPOE_VCPE_TAR_FILE
CONTAINER_VOLUMES=/var/container_volumes; export CONTAINER_VOLUMES
DOCKER_SPINUP_DIR=/usr/local/sbin; export DOCKER_SPINUP_DIR
if [ -f ${HOME_DIR}/$file_vsp_ip ]; then
   echo "$vsgIp" >>${HOME_DIR}/$file_vsg_ip
else
   echo "$vsgIp" >${HOME_DIR}/$file_vsg_ip
fi

echo "Setting up VSG VM Instance $vsgIp ..."

nova_compute_ip=$(ip addr show |grep br-int|grep 172.27|awk '{print $2}'|sed 's/\/24//')
br_wan_ip=$( ssh ubuntu@$vsgIp "/sbin/ifconfig br-wan | grep 'inet addr:' | cut -d: -f2 | awk '{ print \$1}'" )
export nova_compute_ip
export br_wan_ip
echo "Setting VSG instance ($vsg_id) CP_PREFIX=$VCPEPROXY_CP_IP_PREFIX"
vcpe_gwbr_cval=0
vcpe_gwbr_dval=$(( vsg_id + 1 ))
vcpe_gwbr_ip=`echo $VCPEPROXY_CP_IP_PREFIX.$vcpe_gwbr_cval.$vcpe_gwbr_dval`
export vcpe_gwbr_ip 

echo "VCPEGW_BRIDGE_IP in VSG ($VSG_ID).......$vcpe_gwbr_ip"

if [ -f /home/ubuntu/.ssh/known_hosts ]; then
  echo "Removing $vsgIp from /home/ubuntu/.ssh/known_hosts"
  ssh-keygen -f "/home/ubuntu/.ssh/known_hosts" -R $vsgIp 
fi
setup_vcpe_monitoring
vsg_script_transfer
connect_vcpegw_bridge_to_vsg
setup_vcpegw_bridge_in_vsg
start_vcpe_monitoring
date
echo "nova_vsg_setup.sh: End"
