#!/bin/bash
#************************************************************/
#** File:         create-addsubscriber-yaml.sh              */
#** Contents:     Contains shell script to create           */
#**               addsubscriber-yaml file.                  */
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

if [ $# -ne 2 ]; then
 echo "Missing args: Usage: $0 <stag> <ctag>"
 echo "stag=[20-100], ctag=[100 - 500]"
 exit 1
fi
echo "checking stag value"
if [[ $1 -le 20 || $1 -gt 100 ]];then
 echo "Invalid STAG value: Usage $0 <stag> <ctag>"
 echo "stag=[20-100], ctag=[101 - 250]"
 exit 1
fi
echo "checking ctag value"
if [[ $2 -le 101 || $2 -gt 250 ]];then
 echo "Invalid CTAG value: Usage $0 <stag> <ctag>"
 echo "stag=[20-100], ctag=[101 - 250]"
 exit 1
fi
if [ ! -f ./add-subscriber-xxx.yaml ]; then
  echo "Missing test-subscriber-xxx.yaml file"
  exit 1
fi
STAG=$1
CTAG=$2
STAG_HEX=`printf '%02x' $STAG`
CTAG_HEX=`printf '%02x' $CTAG`
yaml_filename=add-subscriber-$STAG-$CTAG.yaml
echo "Creating $yaml_filename file with $STAG($STAG_HEX) $CTAG($CTAG_HEX)"
cp add-subscriber-xxx.yaml $yaml_filename
sed -i s/\#\#CTAG_HEX\#\#/$CTAG_HEX/g $yaml_filename
sed -i s/\#\#STAG_HEX\#\#/$STAG_HEX/g $yaml_filename
sed -i s/\#\#CTAG\#\#/$CTAG/g $yaml_filename
sed -i s/\#\#STAG\#\#/$STAG/g $yaml_filename
echo "$yaml_filename yaml file created successfully"
if [ -d ~/cord_profile ]; then
   read -p "Do you want to copy $yaml_filename to headnode directory (y/[N])? " -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        scp $yaml_filename vagrant@head1:/opt/cord_profile
        echo "$yaml_filename yaml file copied into /opt/cord_profile directory in head1 VM"
    fi
fi
#
# Before manually creating the docker instance verify that the
# docker instance bearing the same name does not exist in vSG VM
#
 echo "To create the Docker instance, login to the head1 VM "
 echo "and execute the following command:"
 echo "****************************************************"
 echo "sudo docker exec -it rcord_xos_ui_1 python /opt/xos/tosca/run.py xosadmin@opencord.org /opt/cord_profile/$yaml_filename"
 echo "****************************************************"
 echo ""
#
# Alternatively, the following command may be executed from the host 
# (headnode) to create the docker instance
# CAUTION: If the following command is used inside a script, the variable
# $yaml_filename may will not be translated since it is within the single quote.
#
# shpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@head1 'sudo docker exec -it rcord_xos_ui_1 python /opt/xos/tosca/run.py xosadmin@opencord.org /opt/cord_profile/$yaml_filename'
#
time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
