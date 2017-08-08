
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
#** File:         nova_vsg_monitor.sh                       */
#** Contents:     Contains shell script to periodically     */
#**               (every minute) check VSG status. If VSG is*/
#**               up calls, prepare vSG with the            */
#**               necessary packages and start vCPE         */
#**               program inside VSG. When vCPE comes up    */
#**               execute vsg_vcep_setup.sh script          */
#************************************************************/
function is_vsg_active() {

    echo "Checking vSG status..."
    vcpe=0
    ping=0
    active=0

    # check if vsg is active, if vsg is not active return 
    if [ 'nova list --all-tenants | grep $1 | grep ACTIVE' ]; then
      active=1
      #echo "VSG is ACTIVE"
    else
      #echo "VSG is not active, exit"
      return 0
    fi

    # check if ping is ok
    if ssh ubuntu@$MGMTIP "ping -c 3 8.8.8.8" > /dev/null; then
      ping=1
      #echo "PING OK"
    fi

    # if all the above checks are ok then vsg is active
    if [[ "$active" == 1 && "$ping" == 1 ]]; then
      #echo "VSG is ACTIVE"
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

function check_vsg_status() {

    source ${HOME_DIR}/admin-openrc.sh

    echo "Checking for new VSG..."

    file_temp="${HOME_DIR}/temp_id.txt"
    file_id="${HOME_DIR}/$PPPOE_VSG_ID_FILE_NAME"

    nova list --all-tenants|grep mysite_vsg|awk '{print $2}' > $file_temp

    getArray $file_temp

    for id in "${array[@]}"
    do
      # if VSG Id does not exist, add it if VSG is active
      if ! grep -q $id "$file_id" > /dev/null; then
        echo "Found new VSG"
        echo "VSG ID=$id"

        MGMTIP=$( nova interface-list $id|grep 172.27|awk '{print $8}' )

        echo "MGMTIP: $MGMTIP"
        if [ ! "$MGMTIP" ];then
          echo "MGMTIP:$MGMTIP is null, continue"
          continue
        fi

        is_vsg_active $MGMTIP $id
        is_active=$?

        if [[ $is_active -eq 1 ]]; then
          echo "VSG is active"
          # add vsg ID to the file
          echo "$id" >> $file_id

          echo "Calling VSG Setup script"
          vsg_id=`cat $file_id|wc -l`
          echo "Setting up vsg_id:.....$vsg_id CP_PREFIX= $VCPEPROXY_CP_IP_PREFIX"
          source ./nova_vsg_setup.sh $MGMTIP $vsg_id
          echo "VSG Instance $vsg_id setup is complete"
        else
          echo "VSG is not active"
        fi
      fi
    done
}

echo "nova_vsg_monitor: Execution Begin"

if [ -z $HOME_DIR ]; then
  echo "HOME_DIR env variable is not...Using current directory as home"
  HOME_DIR=`pwd`
fi

while true
do
    echo "Periodically checking for new VSG"

    MGMTIP=""
    #echo "BEFORE: $MGMTIP"
    check_vsg_status

    date
    printf "\n"
    sleep 60

done
echo "nova_vsg_monitor.sh: Execution End"
