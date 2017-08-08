
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
#** File:         vsg_pppoe_cleanup.sh                      */
#** Contents:     Contains shell script to clean up all     */
#**               artifacts tied to applications            */
#************************************************************/

source /tmp/vsg_env.txt

date
echo "vsg_pppoe_cleanup.sh: Begin"
vsgIp=$1
vcpeproxy_prefix=vcpe; export vcpeproxy_prefix
vcpe_gwbr_name=vcpe_gwbr; export vcpe_gwbr
vsg_home_dir=$2
vcpe_monitor_script=vsg_vcpe_monitor.sh
container_volumes=/var/container_volumes
if [ $# -ne 2 ]
  then
    echo "Usage: vsg_pppoe_cleanup.sh <vsgIp> <vsg_home_dir>"
    exit 0
fi

getArray() {
    array=() # Create array
    while IFS= read -r line # Read a line
    do
        array+=("$line") # Append line to the array
    done < "$1"
}

#
# Restarting a vcpeproxy will force the Docker instance to be cleaned up
# automatically.
# Note: Since vcpeproxy is created from XOS, if you want to delete that
# Docker instance, you will have to go through XOS make cleanup operation.
#
function restart_all_vcpeproxy() {

    echo "Restart all vcpeproxy..."

    file_temp="/tmp/vcpeproxy_names.txt"

    sudo docker ps|grep $vcpeproxy_prefix|awk '{print $NF}' > $file_temp

    getArray $file_temp

    for id in "${array[@]}"
    do
        echo "Restarting docker instance $id"
        sudo docker exec $id sed -i "s/POST/DELETE/g" $NODEJS_MODULES_DIR$AP_REST_NETCFG
        sudo docker exec $id bash $NODEJS_MODULES_DIR$AP_REST_NETCFG
        sudo docker restart $id
    done
}

echo "Killall nodejs programs running in the VSG"
sudo killall nodejs
restart_all_vcpeproxy
if ifconfig -a |grep $vcpe_gwbr_name ; then
   sudo ifconfig $vcpe_gwbr_name down
   sudo brctl delbr $vcpe_gwbr_name
fi
if [ -d $vsg_home_dir ]; then
   rm -rf $vsg_home_dir/*
fi
pid=`ps -fade|grep vsg_vcpe_monitor.sh|grep -v grep |awk '{print $2}'`
if echo $pid|grep [0-9] ; then
   echo "Killing vsg_vcpe_monitor.sh script"
   sudo kill -9 $pid
fi
date
echo "vsg_vcpegw_cleanup.sh: End"
