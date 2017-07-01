#!/usr/bin/env bash
#************************************************************/
#** File:         setup-port-forwarding.sh                  */
#** Contents:     Contains shell script to setup port       */
#**               forwarding from head node to the          */
#**               appropriate VM or docker instance         */
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
source $IPOE_SETUP_DIR/wide-dhcp6.vars

set -e

CORDDIR=~/cord
VMDIR=/cord/build/
EXT_SVR_LIST=""
EXT_USR=cord
EXT_PWD=cord
Fab_EXTIF=eth1; export Fab_EXTIF
Mgmt_EXTIF=eth2; export Mgmt_EXTIF


function set_port_forwarding {
# Fab_BRIDGE=$( route -n | grep 10.6.1.0 | awk '{print $8}' )
#  Mgmt_BRIDGE=$( ip addr show | grep 0.0.0.1 | awk '{print $7}')
#
#  # Change MAC address of bridge to match cord-pod service profile
#  # This change won't survive a reboot
#  sudo ifconfig $Fab_BRIDGE hw ether 02:42:0a:06:01:01
#
#  # Add Gateway IP to Fabric Bridge
#  ip addr list | grep 10.6.1.129 || sudo ip address add 10.6.1.129 dev $Fab_BRIDGE
#  ip addr list | grep 10.6.1.193 || sudo ip address add 10.6.1.193 dev $Fab_BRIDGE
#  ip addr list | grep 192.168.140.1 || sudo ip address add 192.168.140.1/24 dev $Fab_BRIDGE
#
#  #Add External Ethernet Port to Fabric Bridge and Management Bridge
#  sudo brctl show $Fab_BRIDGE |grep $Fab_EXTIF || sudo brctl addif $Fab_BRIDGE $Fab_EXTIF
#  sudo brctl show $Mgmt_BRIDGE |grep $Mgmt_EXTIF || sudo brctl addif $Mgmt_BRIDGE $Mgmt_EXTIF

  echo "*** Set up IP/Port forwarding * on the head node"
  head_ip="$(ifconfig | grep -A 1 -m 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
  echo "Head IP = $head_ip"

  prod_ip="$(grep head1 /var/lib/libvirt/dnsmasq/vagrant-libvirt.leases | cut -d " " -f 3)"

  echo "Prod_IP = $prod_ip"

  if [ -e ~/iptables_orig ]
  then
    echo "Restore the basic IP table"
    sudo iptables-restore < ~/iptables_orig
  else
    echo "save the basic IP table"
    sudo iptables-save > ~/iptables_orig
  fi

#  sudo iptables -I FORWARD -m state -d 192.168.140.0/24 -i virbr1 -o $Fab_BRIDGE -j ACCEPT --state NEW,ESTABLISHED,RELATED
#  sudo iptables -I FORWARD -m state -s 192.168.140.0/24 -i $Fab_BRIDGE  -j ACCEPT --state NEW,ESTABLISHED,RELATED

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp -d 10.100.198.201 --dport 6654 -j DNAT   --to-destination $prod_ip:6654

#  sudo iptables -I INPUT -p gre -j ACCEPT
#  sudo iptables -I FORWARD 16 -p gre -o $Fab_BRIDGE -j ACCEPT

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 80 -j DNAT   --to-destination $prod_ip:80
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 80 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 80 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 8080 -j DNAT   --to-destination $prod_ip:8080
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 8080 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 8080 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 6653 -j DNAT   --to-destination $prod_ip:6653
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 6653 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 6653 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 6654 -j DNAT   --to-destination $prod_ip:6654
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 6654 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 6654 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 8080 -j DNAT   --to-destination $prod_ip:8080
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 8080 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 8080 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 8101 -j DNAT   --to-destination $prod_ip:8101
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 8101 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 8101 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 8181 -j DNAT   --to-destination $prod_ip:8181
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 8181 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 8181 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 8102 -j DNAT   --to-destination $prod_ip:8102
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 8102 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 8102 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp -m tcp   -d $head_ip --dport 8182 -j DNAT   --to-destination $prod_ip:8182
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --dport 8182 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp -m tcp   -s $prod_ip --sport 8182 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp          -d $head_ip --sport 830 -j DNAT   --to $prod_ip
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --sport 830 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp          -s $prod_ip --dport 830 -j SNAT   --to-source $head_ip

  sudo iptables -t nat -I PREROUTING  -p tcp          -d $head_ip --sport 3000 -j DNAT   --to $prod_ip
  sudo iptables        -I FORWARD     -p tcp -m state -d $prod_ip --sport 3000 -j ACCEPT --state NEW,ESTABLISHED,RELATED
  sudo iptables -t nat -I POSTROUTING -p tcp          -s $prod_ip --dport 3000 -j SNAT   --to-source $head_ip
}

# Parse options
GERRIT_BRANCHES=
RUN_TEST=0
SETUP_ONLY=0
DIAGNOSTICS=0
CLEANUP=0
#By default, cord-in-a-box creates 1 compute node. If more than one compute is
#needed, use -n option
NUM_COMPUTE_NODES=1

while getopts "b:cde:hn:stv" opt; do
  case ${opt} in
    c ) CLEANUP=1
      ;;
    h ) echo "Usage:"
      echo "    $0                install OpenStack and prep XOS and ONOS VMs [default]"
      echo "    $0 -c             cleanup from previous test"
      echo "    $0 -h             display this help message"
      exit 0
      ;;
    \? ) echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

# What to do
if [[ $CLEANUP -eq 1 ]]
then
  cleanup_from_previous_test
fi

echo ""
echo "Preparing to setup port forwarding in headnode server...."
echo ""

set_port_forwarding


time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
exit 0
