#!/bin/bash
#************************************************************/
#** File:         setup-nat64.sh                            */
#** Contents:     Contains shell script to reinit nat64     */
#**               and dhcpv6 server in ipoe server VM       */
#************************************************************/
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
     echo "sudo -E /sbin/ip -6 route add $prefix via $IP"  >> /tmp/ipoe.log 2>&1
     sudo -E /sbin/ip -6 route add $prefix via $IP
  done
} 

WIDE_DHCP6_VARS="wide-dhcp6.vars"
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
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi

cd $IPOE_SETUP_DIR
$IPOE_SETUP_DIR/create-bind-conf.sh $WIDE_DHCP6_VARS
$IPOE_SETUP_DIR/create-tayga-conf.sh $WIDE_DHCP6_VARS
$IPOE_SETUP_DIR/create-dhcp6-server-conf.sh $WIDE_DHCP6_VARS dhcp6s.conf
cp $IPOE_SETUP_DIR/dhcp6s.conf /tmp
cp $IPOE_SETUP_DIR/tayga.conf /tmp
cp $IPOE_SETUP_DIR/named.conf.options /tmp	

source $IPOE_SETUP_DIR/$WIDE_DHCP6_VARS
#
# reinit nat64 
#
sudo -E cp  /tmp/tayga.conf /etc/
ipv6addr=`ifconfig nat64|grep Global|awk '{print $3'}`
sudo -E ip addr del $ipv6addr dev nat64
ipv4addr=`ifconfig nat64|grep P-t-P|awk '{print $3'}|awk -F ':' '{print $2'}`
sudo -E ip addr del $ipv4addr dev nat64
sudo -E ip addr add $TAYGA_ROUTER_IPV4_IP dev nat64
sudo -E ip addr add $TAYGA_ROUTER_IPV6_IP dev nat64
sudo -E ip route add $TAYGA_POOL dev nat64
sudo -E ip route add $TAYGA_IPV6_PREFIX dev nat64
echo "Restart tayga..."
sudo -E killall tayga
sudo -E tayga
#
# reinit  nat66
#
OUT_INTF=teredo
sudo -E ip6tables -t nat -A POSTROUTING -o $OUT_INTF --source $IPOE_IPV6_SUB_PREFIX::/48 -j MASQUERADE
#
#reinit Bind 
#
sudo -E cp /tmp/named.conf.options /etc/bind
echo "Restart Bind..."
sudo -E service bind9 restart

touch /tmp/ipoe.log
sudo ifconfig $DHCP6S_IPOE_INTF down
sudo ifconfig $DHCP6S_IPOE_INTF up

source $IPOE_SETUP_DIR/$WIDE_DHCP6_VARS
addr=`ifconfig $DHCP6S_IPOE_INTF|grep Global|awk '{print $3'}`
sudo -E ip addr del $addr dev $DHCP6S_IPOE_INTF
sudo -E ip -f inet6 addr add $IPOE_IPV6_PREFIX::1/64 scope global dev $DHCP6S_IPOE_INTF
echo "sudo -E ip -f inet6 addr add $IPOE_IPV6_PREFIX::1/64 scope global dev $DHCP6S_IPOE_INTF"  >> /tmp/ipoe.log 2>&1
#
# reinit dhcpv6 server
#
sudo -E cp /tmp/dhcp6s.conf /etc/wide-dhcpv6
echo "Restart DHCP6 server..."
sudo -E /etc/init.d/wide-dhcpv6-server stop
sudo -E /usr/sbin/dhcp6s -D -k /dev/null -P /var/run/dhcp6s.$DHCP6S_IPOE_INTF.pid $DHCP6S_IPOE_INTF
echo "Add routes ..."
generate_routes

sudo killall tcpdump
echo "Capture the DHCP6 packets ...."
nohup sudo tcpdump -tttt -l -i eth1 -n -e -vvv port 546 or port 547  > /tmp/dhcp6-cap.log 2>&1 &

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"

