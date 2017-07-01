#!/bin/bash
#************************************************************/
#** File:         vCPE-Monitor.sh                           */
#** Contents:     Contains shell script to setup vcpe docker*/
#**               instance                                  */
#************************************************************/

time_begin=`date`
echo "$0: Script execution begins: $time_begin"

if [ -z "$IPOE_SETUP_DIR" ]; then 
  if [ "$CORD_ENV" == "true" ]; then
      IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  else
      IPOE_SETUP_DIR=/cord/ipoe-setup
  fi
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi

if [ -z "$WIDE_DHCP6_VARS" ]; then
   WIDE_DHCP6_VARS="wide-dhcp6.vars"
   echo "Using $WIDE_DHCP6_VARS as IPOE_IPV6 setup vars"
fi

if ! [ $# -eq 1 ]; 
then
   echo "Missing Argument error..."
   echo "Usage: $0 <VCPE_DOCKER_NAME>"
   exit 0
else
   VCPE_DOCKER_NAME=$1
fi
VCPE_DOCKER_NAME=`echo $VCPE_DOCKER_NAME| tr '[:upper:]' '[:lower:]'`

cd $IPOE_SETUP_DIR

echo "Create $VCPE_DOCKER_NAME yml "
$IPOE_SETUP_DIR/create-vcpe-docker-yml.sh $VCPE_DOCKER_NAME

echo "Create $VCPE_DOCKER_NAME docker network instance"
docker-compose -f docker-$VCPE_DOCKER_NAME.yml up -d

docker exec -it $VCPE_DOCKER_NAME ping -c 10 8.8.8.8 >/dev/null

if [ $? != 0 ]; then
  echo "Destination Host Unreachable !"
  echo "WARNING...Unable to reach VCPE docker..."
fi

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"

