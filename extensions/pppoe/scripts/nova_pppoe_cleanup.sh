
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


#!/bin/bash
#************************************************************/
#** File:         nova_pppoe_cleanup.sh                     */
#** Contents:     Contains shell script to clean up         */
#**               nova-compute VM                           */
#************************************************************/

date
echo "nova_pppoe_cleanup.sh: Begin"

HOME_DIR=`pwd`; export HOME_DIR
vsg_monitor_script="nova_vsg_monitor.sh"
vsg_cleanup_script="vsg_pppoe_cleanup.sh"
vsg_gwbr_name=vsg_gwbr
vsg_home_dir=/home/ubuntu
vsg_env_file=vsg_env.txt
# Read the temp_id.txt file and fill the array named "array"

getArray() {
    array=() # Create array
    while IFS= read -r line # Read a line
    do
        array+=("$line") # Append line to the array
    done < "$1"
}

get_vsg_gwbr_ifaces() {
    ifacesArray=() # Create array
    while IFS= read -r line # Read a line
    do
        ifacesArray+=("$line") # Append line to the array
    done < "$1"
}

function cleanup_vsg_dockers() {

    source ${HOME_DIR}/admin-openrc.sh

    echo "Checking for active VSG..."

    file_temp="${HOME_DIR}/temp_id.txt"

    nova list --all-tenants|grep mysite_vsg|grep ACTIVE|awk '{print $2}' > $file_temp

    getArray $file_temp

    for id in "${array[@]}"
    do
        echo "VSG ID=$id"
        vsgIp=$( nova interface-list $id|grep 172.27|awk '{print $8}' )
        echo "Cleaning up VSG: vsgIp: $vsgIp"
        scp $HOME_DIR/$vsg_cleanup_script "ubuntu@$vsgIp:/tmp"
        scp $HOME_DIR/$vsg_env_file "ubuntu@$vsgIp:/tmp"
        ssh ubuntu@$vsgIp "chmod +x /tmp/$vsg_cleanup_script"
        ssh ubuntu@$vsgIp "/tmp/$vsg_cleanup_script $vsgIp $vsg_home_dir"
        echo "VSG Instance $vsgIp cleanup is complete"
    done
}

function cleanup_vsg_gwbr() {

    echo "Entering function_cleanup_vsg_gwbridge "
    source ${HOME_DIR}/admin-openrc.sh

    file_temp="${HOME_DIR}/vsg_id.txt"
    file_ifaces="${HOME_DIR}/gwbr_ifaces.txt"

    sudo virsh list|awk '{print $1}' > $file_temp

    getArray $file_temp

    for id in "${array[@]}"
    do
      len=${#id}
      if [ $len -eq 0 ] || echo $id|grep [^0-9]; then
        echo "Not a valid virsh ID: $id"
      else
        echo "Cleaning up VSG instance: $id"
        sudo virsh domiflist $id|grep $vsg_gwbr_name|awk '{print $NF}' > $file_ifaces
        get_vsg_gwbr_ifaces $file_ifaces
        for mac in "${ifacesArray[@]}"
        do
           echo "Detaching interface $mac in VSG instance: $id"
           sudo virsh detach-interface $id bridge $mac
        done
        echo "VSG Instance $id cleanup is complete"
      fi 
    done
    if ifconfig -a |grep $vsg_gwbr_name; then
       sudo ifconfig $vsg_gwbr_name down
       sudo brctl delbr $vsg_gwbr_name 
    fi
}

function remove_temp_files () {
    sudo rm -f $HOME_DIR/*.txt 
}

function remove_apps() {
    echo "Removing Apps"
    sudo rm -rf /usr/local/pppoe/utils/
    sudo rm -rf /usr/local/pppoe
}

function stop_vsg_monitor() {
    echo "Stopping pppoe_check_vsg_status.sh script"
    pid=`ps -ef | grep $vsg_monitor_script| grep -v grep | awk '{print $2}'` 
    if [ -n $pid ]; then
       sudo kill -9 $pid
    fi
    rm -rf $HOME_DIR/nova_vsg_monitor.log
}

function stop_nova_consolidator() {
    echo "Stopping nova consolidation app"
    $HOME_DIR/nova_consolidator_stop.sh
    sudo rm -f /usr/local/lib/node_modules/*.json
}

#remove_vsg_entry_from_proxy_file
#delete_vsg_id
stop_vsg_monitor
remove_apps
cleanup_vsg_dockers
cleanup_vsg_gwbr
stop_nova_consolidator
remove_temp_files
echo "nova_pppoe_cleanup.sh: End"
date
