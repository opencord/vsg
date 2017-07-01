#!/bin/bash
#************************************************************/
#** File:         create-udata.sh                           */
#** Contents:     Contains shell script to create meta data */
#**               for ipoe-server virtual machine.          */
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
  echo "Usage: create_udata.sh <user_data_file> <VM_NAME>"
  exit 1
fi
if [ ! -f /home/ubuntu/.ssh/id_rsa.pub ]; then
   echo "Warning..id_rsa.pub does not existing. Generating new key pair"
   ssh-keygen -f /home/ubuntu/.ssh/id_rsa -b 2048 -t rsa -N ''
fi
SSH_PUBKEY=`cat /home/ubuntu/.ssh/id_rsa.pub`
USER_DATA=$1
VM_NAME=$2
echo "Generating user_data with SSH_KEY=$SSH_PUBKEY"
cat > $USER_DATA << _EOF_
#cloud-config

# Configure where output will go
output: 
  all: ">> /var/log/cloud-init.log"

# Install cloud-init
bootcmd:
  - [ apt-get, -y, install, cloud-init ]

ssh_svcname: ssh
ssh_deletekeys: True
ssh_genkeytypes: ['rsa', 'ecdsa']

 
# Hostname management
manage_etc_hosts: true
preserve_hostname: false
hostname: $VM_NAME
fqdn: $VM_NAME.opencon.com

password: ubuntu
chpasswd: { expire: False }
ssh_pwauth: True

# Install my public ssh key to the first user-defined user configured 
# in cloud.cfg in the template 
ssh_authorized_keys:
  - $SSH_PUBKEY 

_EOF_

sleep 1
echo "USER_DATA file successfully generated..."
cat $USER_DATA
time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
