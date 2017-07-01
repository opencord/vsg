#!/bin/bash
#************************************************************/
#** File:         create-vcpe-docker-yml.sh              */
#** Contents:     Contains shell script to create           */
#**               vcp docker yml file.                      */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"
 
if ! [ $# -eq 1 ]; 
then
   echo "Missing Argument error..."
   echo "Usage: $0 <VCPE_DOCKER_NAME>"
   exit 0
else
   VCPE_DOCKER_NAME=$1
fi
VCPE_DOCKER_NAME=`echo $VCPE_DOCKER_NAME| tr '[:upper:]' '[:lower:]'`

DOCKERYML=docker-$VCPE_DOCKER_NAME.yml
cat > $DOCKERYML<< _EOF_
# ONOS with XOS features for docker-compose
version: '2'

services:
   $VCPE_DOCKER_NAME:
      privileged: true
      tty: true
      image: cord/tester
      container_name: "$VCPE_DOCKER_NAME"
      hostname: $VCPE_DOCKER_NAME
      domainname: opencord.org
      volumes:
       - /dev/bus/usb:/dev/bus/usb:rw
#       - /cord/oai-server:/root/cord/oai-server:rw

_EOF_
time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
