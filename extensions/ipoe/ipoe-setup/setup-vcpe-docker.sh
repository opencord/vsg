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

  if [ "$CORD_ENV" == "true" ]; then
      IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  else
      IPOE_SETUP_DIR=/cord/ipoe-setup
  fi
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi
cd $IPOE_SETUP_DIR
source $WIDE_DHCP6_VARS


if [ ! -f $WIDE_DHCP6_VARS ]; then
  echo "Missing $WIDE_DHCP6_VARS wide-dhc6c-client configuration file"
  exit 1
fi
if [ -z "$wide_dhcp6c_raw_script" ]; then
   wide_dhcp6c_raw_script="wide-dhcp6c-script.raw"
   echo "Using $wide_dhcp6c_raw_script as unprocessed wide-dhcpc6c-script.sh"
fi

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

if [[ $EUID -ne 0 ]]; then
  group_mem=`id|grep docker`
  if [ -z "$group_mem" ]; then
     echo "Please run this script with sudo command"
     exit 0
  else
     echo "Using docker group membership privileges"
  fi
else
  echo "Running the script in Sudo mode"
fi
touch /tmp/vcpe.log
echo "Docker instance $TARGET_DOCKER_NAME " >> /tmp/vcpe.log 2>&1
docker inspect $TARGET_DOCKER_NAME >> /dev/null

if [ "$?" == 0 ]
then

   echo "Docker instance $TARGET_DOCKER_NAME is up and running"
   extract_stag_ctag
else
   echo "Docker instance $TARGET_DOCKER_NAME is not up"
   exit 1
fi

if [ -z "$MAC_PREFIX" ]; then
   MAC_PREFIX="00:0E:00:10"
   echo "Using $MAC_PREFIX as the mac_prefix for DHCPv6 DUID"
fi
if [ -z "$IPOE_IPV6_PREFIX" ]; then
   IPOE_IPV6_PREFIX="FD64:8D64:AF0C:1" 
   echo "Using $IPOE_IPV6_PREFIX as IPV6 prefix..."
fi
docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "echo 0 >/proc/sys/net/ipv6/conf/all/disable_ipv6"

#Limit the CTAG value to 250 so that it can be used for MAC/IPv4 address.
ctag_mod=$(( $CTAG%250 ))
stag_mod=$(( $STAG%250 ))
stag_mod_hex=`printf '%02x' $stag_mod`
ctag_mod_hex=`printf '%02x' $ctag_mod`
dhcp6c_conf_file="dhcp6c-$stag_mod-$ctag_mod.conf"
radvd_script_file="radvd-$stag_mod-$ctag_mod.sh"
if [ ! -f $dhcp6c_conf_file ]; then
  echo "Error..Missing $dhcp6c_conf_file...."
  echo "Use create-dhcp6-client-conf.sh to generate client config file"
  exit 1
fi
if [ ! -f $radvd_script_file ]; then
  echo "Error..Missing $radvd_script_file...."
  echo "Use create-dhcp6-client-conf.sh to generate radvd_script file"
  exit 1
fi
if [ "$CORD_ENV" == "true" ]; then
LAN_IFACE=eth0
ifconfig $LAN_IFACE.$STAG >> /dev/null
if [ "$?" != 0 ]
then
#
# This part of the code is used only in local test environment
# created outside Cord4.0
#
    LAN_IFACE=eth1
    sudo ifconfig $LAN_IFACE up
    sudo ifconfig $LAN_IFACE.$STAG >> /dev/null || sudo ip link add link $LAN_IFACE name $LAN_IFACE.$STAG type vlan id $STAG
    sudo ifconfig $LAN_IFACE.$STAG up
    sleep 5
    NUMB=`expr 1 + $ctag_mod`
    PIPEIP="192.168.0.$NUMB/24"
    docker exec $TARGET_DOCKER_NAME ifconfig eth1 >> /dev/null || sudo /usr/local/bin/pipework $LAN_IFACE.$STAG -i eth1 $TARGET_DOCKER_NAME $PIPEIP @$CTAG
fi
else
LAN_IFACE=eth1
ifconfig $LAN_IFACE >> /dev/null
if [ "$?" == 0 ]
then
    sudo ifconfig $LAN_IFACE up
    sudo ifconfig $LAN_IFACE.$STAG >> /dev/null || sudo ip link add link $LAN_IFACE name $LAN_IFACE.$STAG type vlan id $STAG
    sudo ifconfig $LAN_IFACE.$STAG up
    sleep 5
    PIPEIP="192.168.0.$ctag_mod/24"
    echo "PIPEIP :$TARGET_DOCKER_NAME ,$PIPEIP , $CTAG" >> /tmp/vcpe.log 2>&1
    docker exec $TARGET_DOCKER_NAME ifconfig eth1 >> /dev/null || sudo /usr/local/bin/pipework $LAN_IFACE.$STAG -i eth1 $TARGET_DOCKER_NAME $PIPEIP @$CTAG
fi
fi
if [ "$CORD_ENV" == "true" ]; then
IPOE_IFACE=eth2
ifconfig $IPOE_IFACE >> /dev/null
if [ "$?" == 0 ]
then
    sudo ifconfig $IPOE_IFACE up
    #NUM_HEX=`printf '%02x' $stag_mod`
    IP="$IPOE_IPV6_PREFIX::$stag_mod_hex:$ctag_mod_hex/64"
    docker exec $TARGET_DOCKER_NAME ifconfig $IPOE_IFACE >> /dev/null || sudo /usr/local/bin/pipework ipoe-intbr -i $IPOE_IFACE $TARGET_DOCKER_NAME $IP@$IPOE_IPV6_PREFIX::1
    sleep 1
    docker exec $TARGET_DOCKER_NAME ip -f inet6 addr del $IP dev $IPOE_IFACE
fi
else
IPOE_IFACE=eth2
IP="$IPOE_IPV6_PREFIX::$stag_mod_hex:$ctag_mod_hex/64"
docker exec $TARGET_DOCKER_NAME ifconfig $IPOE_IFACE >> /dev/null || sudo /usr/local/bin/pipework ipoe-intbr -i $IPOE_IFACE $TARGET_DOCKER_NAME $IP@$IPOE_IPV6_PREFIX::1
sleep 1
docker exec $TARGET_DOCKER_NAME ip -f inet6 addr del $IP dev $IPOE_IFACE
fi

#
# Set up the docker instance to perform IPv6 packet forwarding
# from eth1 to eth2 interface that is attached to the ipoe-server.
#

echo "Configuring ipv6 networking in Docker"
echo "Setting the hostname of docker as $TARGET_DOCKER_NAME"
docker exec -i $TARGET_DOCKER_NAME hostname -b $TARGET_DOCKER_NAME
docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "echo 0 >/proc/sys/net/ipv6/conf/eth2/autoconf"
docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "echo 1 >/proc/sys/net/ipv6/conf/all/forwarding"
docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "echo 2 >/proc/sys/net/ipv6/conf/eth2/accept_ra"
if [ "$LAN_IFACE" == "eth1" ]; then
  docker exec -i $TARGET_DOCKER_NAME ip route add 0.0.0.0/0 via 172.20.0.1 dev eth0
else
  docker exec -i $TARGET_DOCKER_NAME ip route add 0.0.0.0/0 via 10.7.1.1 dev eth0
fi

echo "Installing wide-dhcpv6 client , dibbler server ,radvd in docker"
docker exec -i $TARGET_DOCKER_NAME apt list --installed | grep dibbler-server > /dev/null 2>&1
if [ $? -ne 0 ]; then
  docker exec -i $TARGET_DOCKER_NAME /bin/bash -c " apt-get update"
  docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "echo eth2| apt-get install -y wide-dhcpv6-client dibbler-server radvd psmisc"
fi

echo "Generating dhcpv6_duid for docker"
DOCKER_ID="$MAC_PREFIX:$stag_mod_hex:$ctag_mod_hex"
echo "$TARGET_DOCKER_NAME DOCKER_ID = $DOCKER_ID" >> /tmp/vcpe.log 2>&1
python $IPOE_SETUP_DIR/dhcp6_duid.py $DOCKER_ID $TARGET_DOCKER_NAME
echo "Copying dhcpv6 config files to docker instance"
docker cp /tmp/duid_$TARGET_DOCKER_NAME $TARGET_DOCKER_NAME:/var/lib/dhcpv6/dhcp6c_duid
docker cp /tmp/duid_value_$TARGET_DOCKER_NAME $TARGET_DOCKER_NAME:/var/lib/dhcpv6/dhcp6c_duid_value

#
# The following commands should be executed in create-dhcp6-client-conf.sh
# No need to re-execute commands.
#
#cat $IPOE_SETUP_DIR/$wide_dhcp6c_raw_script|sed -e "s/\@\@ipoe_ipv6_sub_prefix\@\@/$IPOE_IPV6_SUB_PREFIX/g" >$IPOE_SETUP_DIR/$WIDE_DHCP6C_SCRIPT
#echo $DHCP6C_LAN_INTF
#sed -i -e "s/\@\@dhcp6c_lan_intf\@\@/$DHCP6C_LAN_INTF/g" $IPOE_SETUP_DIR/$WIDE_DHCP6C_SCRIPT
docker cp $IPOE_SETUP_DIR/$dhcp6c_conf_file $TARGET_DOCKER_NAME:/etc/wide-dhcpv6/dhcp6c.conf
docker cp $IPOE_SETUP_DIR/$WIDE_DHCP6C_SCRIPT $TARGET_DOCKER_NAME:/etc/wide-dhcpv6/$WIDE_DHPC6C_SCRIPT
docker cp $IPOE_SETUP_DIR/$radvd_script_file $TARGET_DOCKER_NAME:/etc/wide-dhcpv6/$RADVD_SCRIPT

echo "Restarting wide-dhcpv6-client. and disabling ufw.."
if [ "$CORD_ENV" == "true" ]; then
####docker exec -it $TARGET_DOCKER_NAME /bin/bash -c "/etc/init.d/wide-dhcpv6-client restart"
  echo "Stopping dnsmasq...ignore the message--- No such file or directory."
  docker exec -i $TARGET_DOCKER_NAME mv -f /etc/service/dnsmasq-safe/run /etc/service/dnsmasq-safe/run.save
  docker exec -i $TARGET_DOCKER_NAME mv -f /etc/service/dnsmasq/run /etc/service/dnsmasq/run.save
  docker exec -i $TARGET_DOCKER_NAME killall dnsmasq
  docker exec -i $TARGET_DOCKER_NAME ps -fade|grep dnsmasq
  echo "Disabling ufw"
  docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "ufw disable;ufw status"
  docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "/etc/init.d/wide-dhcpv6-client stop"
  sleep 1
  echo "starting dhcp6c client"
  docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "dhcp6c -D -c /etc/wide-dhcpv6/dhcp6c.conf $IPOE_IFACE"
else
docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "/etc/init.d/wide-dhcpv6-client stop"
docker exec -i $TARGET_DOCKER_NAME /bin/bash -c "dhcp6c  -c /etc/wide-dhcpv6/dhcp6c.conf eth2"
fi

time_end=`date`
echo "Begin $time_begin" > $vsg_home_dir/$TARGET_DOCKER_NAME
echo $TARGET_DOCKER_NAME >> $vsg_home_dir/$TARGET_DOCKER_NAME
echo "End $time_end" >> $vsg_home_dir/$TARGET_DOCKER_NAME
echo "Script execution completed successfully: $time_end"
echo "setup-vcpe-docker.sh: End"





