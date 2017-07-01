#!/bin/bash
#************************************************************/
#** File:         setup-vcpe-docker.sh                      */
#** Contents:     Contains shell script to setup vcpe docker*/
#**               running inside the vSG virtual machine.   */
#************************************************************/

time_begin=`date`
echo "vsg_vcpe_proxy_setup.sh: Begin"
echo "Script execution begins: $time_begin"

if ! [ $# -eq 2 ]; 
then
   echo "Missing Argument error..."
   echo "Usage: $0 <docker name> <wide-dhcp-vars-file>"
   exit 0
else
   TARGET_DOCKER_NAME=$1
   TARGET_DOCKER_NAME=`echo $TARGET_DOCKER_NAME| tr '[:upper:]' '[:lower:]'`
   export TARGET_DOCKER_NAME
   WIDE_DHCP6_VARS=$2   
fi

if [ -z "$IPOE_SETUP_DIR" ]; then
  echo "Warning...IPOE_SETUP_DIR is not setup. Source from default location.."
  if [ -f /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS ]; then
    source /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS
  else
    source /cord/ipoe-setup/$WIDE_DHCP6_VARS
  fi

fi
if [ "$CORD_ENV" == "true" ]; then
      IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
else
     IPOE_SETUP_DIR=/cord/ipoe-setup
fi
echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi
cd $IPOE_SETUP_DIR
source $WIDE_DHCP6_VARS

function extract_stag_ctag() {
   echo "Entering extract_stag_ctag function.."
   VCPE_NAME=$TARGET_DOCKER_NAME
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
extract_stag_ctag
#Limit the CTAG value to 250 so that it can be used for MAC/IPv4 address.
ctag_mod=$(( $CTAG%250 ))
stag_mod=$(( $STAG%250 ))
stag_mod_hex=`printf '%02x' $stag_mod`
ctag_mod_hex=`printf '%02x' $ctag_mod`

source $IPOE_SETUP_DIR/$WIDE_DHCP6_VARS
IP="$IPOE_IPV6_PREFIX::$stag_mod_hex:$ctag_mod_hex/64"
echo "IPOE_IPV6_PREFIX=$IPOE_IPV6_PREFIX"

sudo docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "ifconfig $DHCP6C_WAN_INTF up"
sudo docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "ip -f inet6 addr add $IP scope global dev $DHCP6C_WAN_INTF"
sudo docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "route -A inet6 add default gw $IPOE_IPV6_PREFIX::1"
sudo docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "ip addr del $IP dev $DHCP6C_WAN_INTF"
sudo docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "dhcp6c  -c /etc/wide-dhcpv6/dhcp6c.conf $DHCP6C_WAN_INTF"

time_end=`date`
echo "Script execution completed successfully: $time_end"
echo "setup-vcpe-docker.sh: End"





