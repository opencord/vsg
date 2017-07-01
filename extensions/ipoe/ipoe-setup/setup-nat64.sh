#!/bin/bash
#************************************************************/
#** File:         setup-nat64.sh                            */
#** Contents:     Contains shell script to configure tayga  */
#**               NAT64 package                             */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

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
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi


cd $IPOE_SETUP_DIR
source $WIDE_DHCP6_VARS
$IPOE_SETUP_DIR/create-bind-conf.sh $WIDE_DHCP6_VARS
$IPOE_SETUP_DIR/create-tayga-conf.sh $WIDE_DHCP6_VARS
cp $IPOE_SETUP_DIR/tayga.conf /tmp
cp $IPOE_SETUP_DIR/named.conf.options /tmp	

#setup tayga start
sudo apt-get install tayga -y
#
# If the IPoE server is attached to an external IPv4 only
# network, then a IPv6 over IPv4 UDP tunnel to
# an external router which can route IPv6 packet to its
# destination. The IPv6 over IPv4 UDP is defined by
# MicroSoft. It is also referred to as "Teredo Tunnel" 
#
# miredo package is the package that is used to 
# create a Teredo UDP tunnel from Ubuntu server to an
# external site from which IPv6 connectivity is available.
#

sudo apt-get install miredo -y
#
sudo cp  /tmp/tayga.conf /etc/
#Create the interface and assign IPv4 and IPv6 addresses, and brought up
sudo tayga --mktun   
sudo ip link set nat64 up
#
sudo ip addr add $TAYGA_ROUTER_IPV4_IP dev nat64
sudo ip addr add $TAYGA_ROUTER_IPV6_IP dev nat64
sudo ip route add $TAYGA_POOL dev nat64
sudo ip route add $TAYGA_IPV6_PREFIX dev nat64
#
sudo tayga
#Translate the source address  to the public IPv4 address with iptables cmds:
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o nat64 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i nat64 -o eth0 -j ACCEPT
# Teredo tunnel allows only communication between the
# host where it is installed to the external IPv6 router
# site. In order for the IPv6 traffic to be routed
# through the Teredo tunnel, NAT66 function is needed.
# The NAT66 rules are created using ip6table NAT table
# entry.

OUT_INTF=teredo
IN_INTF=$DHCP6S_IPOE_INTF
sudo -E ip6tables -t nat -A POSTROUTING -o $OUT_INTF --source $IPOE_IPV6_SUB_PREFIX::/48 -j MASQUERADE
sudo -E ip6tables -A FORWARD -i $OUT_INTF -o $IN_INTF -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo -E ip6tables -A FORWARD -i $IN_INTF -o $OUT_INTF -j ACCEPT

sudo -E sh -c "echo 1 > /proc/sys/net/ipv6/conf/all/forwarding"
sudo -E sh -c "echo 1 > /proc/sys/net/ipv4/conf/all/forwarding"
sudo -E sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
#
#setup Bind start
#
sudo apt-get install bind9 -y
sudo cp /tmp/named.conf.options /etc/bind
sudo service bind9 restart
#setup nat64 end #

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"

