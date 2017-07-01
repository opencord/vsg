#!/bin/bash
#***************************************************************/
#** File:         setup-dhcp6-server.sh                        */
#** Contents:     Contains shell script to setup env for       */
#**               running DHCP6 server in IPOE virtual machine.*/
#***************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

function extract_stag_ctag() {
   vcpe_substrings=$( echo $VCPE_NAME | tr "-" "\n" )
   i=0
   for str in $vcpe_substrings
   do
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

function generate_routes(){
  IFS=',' read -ra vcpe_names <<< "$VCPE_DOCKER_NAMES"
  let j=0
  for i in "${vcpe_names[@]}"
  do
     echo "Docker name[$j]: $i"
     IFS=':' read -ra vcpe_params <<< "$i"
     vcpe_dock_name="${vcpe_params[0]}"
     VCPE_NAME=$vcpe_dock_name
     extract_stag_ctag
     ctag_mod=$(( $CTAG%250 ))
     stag_mod=$(( $STAG%250 ))
     stag_mod_hex=`printf '%02x' $stag_mod`
     ctag_mod_hex=`printf '%02x' $ctag_mod`
     IP="$IPOE_IPV6_PREFIX::$stag_mod_hex$ctag_mod_hex"
     prefix="$IPOE_IPV6_SUB_PREFIX:$stag_mod_hex$ctag_mod_hex::/64"
     echo "sudo /sbin/ip -6 route add $prefix via $IP"
     sudo /sbin/ip -6 route add $prefix via $IP
  done
} 

if [ -z "$WIDE_DHCP6_VARS" ]; then
   WIDE_DHCP6_VARS="wide-dhcp6.vars"
   echo "Using $WIDE_DHCP6_VARS as IPOE_IPV6 setup vars"
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

cd $IPOE_SETUP_DIR
source $WIDE_DHCP6_VARS
$IPOE_SETUP_DIR/create-dhcp6-server-conf.sh $WIDE_DHCP6_VARS dhcp6s.conf
cp $IPOE_SETUP_DIR/dhcp6s.conf /tmp
cp $IPOE_SETUP_DIR/rest-api.tar.gz /tmp
cp $IPOE_SETUP_DIR/extract-dhcp6-leases.sh /tmp

#
# Get all IPv6 addresses assigned to the DHCP6S_IPOE_INTF interface.
# and delete them
#

ipv6_addr_list=`sudo ifconfig $DHCP6S_IPOE_INTF|grep Global|awk '{print $3}'`
i=0
echo "Cleaning up $ipv6_addr_list"
if [ ! -z "$ipv6_addr_list" ]; then
   IFS=' ' read -ra ipv6_addr <<< $ipv6_addr_list
   for addr in "${ipv6_addr[@]}"
   do
      i=$(( i+1 ))
      echo "IPV6 address[$i]=$addr"
      sudo ip addr del $addr dev $DHCP6S_IPOE_INTF
   done
fi

#addr=`ifconfig $DHCP6S_IPOE_INTF|grep Global|awk '{print $3'}`
#sudo ip addr del $addr dev $DHCP6S_IPOE_INTF

sudo ip addr add $IPOE_IPV6_PREFIX::1/64 scope global dev $DHCP6S_IPOE_INTF

sudo apt-get update
#setup dhcp6s start #
sudo apt-get install -y wide-dhcpv6-server
sudo cp /tmp/dhcp6s.conf /etc/wide-dhcpv6
sudo /etc/init.d/wide-dhcpv6-server stop
#setup dhcp6s end  #
cd /tmp
#setup rest api start #
echo "Installing nodejs and npm  in ipoe-server vm"
sudo apt-get install -y nodejs  npm
echo "Installing line-reader , json-server,bluebird  in ipoe-server vm"
sudo npm install -g json-server@0.8.12 bluebird line-reader
#setup rest api end #

#Copy Rest Api codes#
sudo cp /tmp/rest-api.tar.gz /usr/local/lib/node_modules/
cd /usr/local/lib/node_modules/
sudo tar -zxvf rest-api.tar.gz

echo "starting DHCP6 server..."
sudo /usr/sbin/dhcp6s -D -c /etc/wide-dhcpv6/dhcp6s.conf -k /dev/null -P /var/run/dhcp6s.$DHCP6S_IPOE_INTF.pid $DHCP6S_IPOE_INTF
#sudo /usr/sbin/dhcp6s  -c /etc/wide-dhcpv6/dhcp6s.conf $DHCP6S_IPOE_INTF
echo "Starting nodejs server ..."
killall -q nodejs
nohup nodejs -i server.js $IPOE_MGMT_PORT $IPOE_SETUP_DIR/$WIDE_DHCP6_VARS > /tmp/rest.log 2>&1 &
echo "Add routes ..."
generate_routes
echo "Starting NAT64 TAYGA...server"
$IPOE_SETUP_DIR/setup-nat64.sh

echo "Capture the DHCP6 packets ...."
#sudo tcpdump -tttt -l -i eth1 -n -vv port 546 or port 547 2>&1 |tee /tmp/dhcp6-cap.log
nohup sudo tcpdump -tttt -l -i eth1 -n -e -vvv port 546 or port 547  > /tmp/dhcp6-cap.log 2>&1 &

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"

