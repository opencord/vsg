
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
#** File:         vsg_vcpe_monitor.sh                       */
#** Contents:     Contains shell script to periodically     */
#**               (every 30s) check VCPE status. If vcpe is */
#**               up , install packages and report the      */
#**               status via NETCFG consolidator to ONOS.   */
#**               Note: This scripts runs inside VSG        */
#************************************************************/

echo "vsg_vcpe_monitor.sh Script Execution: Begin"

function is_vcpe_active() {

    echo "Checking vCPE status of docker instance : $1"
    vcpe=0
    ping=0
    active=0
   if sudo docker ps -a|grep $1|grep Up >/dev/null ; then
      active=1
   fi
   if [[ $active -eq 0 ]]; then
     return 0
   fi 
    # check if ping is ok
   if sudo docker exec -t $1 ping -c 3 8.8.8.8 > /dev/null; then
      return 1
   else
      return 0
   fi
}

# Read the temp_id.txt file and fill the array named "array"
getArray() {
    array=() # Create array
    while IFS= read -r line # Read a line
    do
        array+=("$line") # Append line to the array
    done < "$1"
}

function check_vcpe_status_and_setup_vcpeproxy() {

    echo "Checking for new vcpe..."

    temp_vcpe_file="${HOME_DIR}/temp_vcpe.txt"
    active_vcpe_file="${HOME_DIR}/$file_vcpe_names"
 
    sudo docker ps -a |grep vcpe-|grep Up|awk '{print $NF}' > $temp_vcpe_file

    getArray $temp_vcpe_file

    for name in "${array[@]}"
    do
      # if vcpename does not exist, add it if vCPE is Up
      if ! grep -q $name "$active_vcpe_file" > /dev/null; then
        echo "Found new VCPE"
        echo "VCPE NAME=$name"

        is_vcpe_active $name
        is_active=$?

        if [[ $is_active -eq 1 ]]; then
          echo "VCPE: $name is active"
          # add vcpe name to the file
          echo "$name" >> $active_vcpe_file
          vcpe_id=`cat $active_vcpe_file|wc -l` 
          echo "Set up vcpe docker $name as VCPE APP proxy: [name=$name] [vsgId=$vsg_id] [vcpe_id=$vcpe_id]"
          source $vsg_home_dir/$vsg_vcpe_proxy_setup_script $name $vsg_id $vcpe_id  
        else
          echo "No new activei vcpe is found"
        fi 
      fi
    done
}

if [ -z $VSG_ENV_FILE ]; then
   echo "WARNING:******VSG_ENV_FILE is not set ..."
fi
if [ -z $HOME_DIR ]; then
   echo "HOME_DIR is not set...."
   HOME_DIR=`pwd`;export HOME_DIR 
fi

if [ -z $vsg_id ]; then
   echo "WARNING:******* vsg_id is not set..."
   vsg_id=1
fi
VSG_ID=$vsg_id; export VSG_ID
while true
do
    echo "Periodically checking for new VCPE Docker instance"

    check_vcpe_status_and_setup_vcpeproxy
    date
    printf "\n"
    sleep 30
done
echo "vsg_vpce_monitor.sh Execution : End"
