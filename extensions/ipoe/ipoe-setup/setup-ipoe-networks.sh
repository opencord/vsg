#!/bin/bash
#************************************************************/
#** File:         setup-ipoe-networks.sh                    */
#** Contents:     Contains shell script to setup ipoe network*/
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

function generate_mac_address()
{
#  uuid_val=`uuidgen`
  mac_addr_prefix="52:53:8E"
  IFS='-' read -ra uuid_parts <<< "$uuid_val"
  part1_str="${uuid_parts[1]:0:2}"
  part2_str="${uuid_parts[2]:0:2}"
  part3_str="${uuid_parts[3]:0:2}"
  echo "$uuid_val $part1_str $part2_str $part3_str"
  gen_mac_address="$mac_addr_prefix:$part1_str:$part2_str:$part3_str"
  echo "Generated MAC address = $gen_mac_address"
}


if [ -z "$IPOE_SETUP_DIR" ]; then
  IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
  echo "Using $IPOE_SETUP_DIR as ipoe-setup dir"
fi
if [ -z "$vsg_home_dir" ]; then
   vsg_home_dir=/home/ubuntu
   echo "Using $vsg_home_dir as vsg_home_dir"
fi
source $IPOE_SETUP_DIR/wide-dhcp6.vars

uuid_val=`uuidgen`
generate_mac_address
echo "Using generated mac address $gen_mac_address for nni-uplinkbr"
echo "Using $uuid_val to generate nni-network.xml file"
cat > nni-network.xml << _EOF_
<network ipv6='yes'>
  <name>nni-network</name>
  <uuid>$uuid_val</uuid>
  <bridge name='nni-uplinkbr' stp='off' delay='0'/>
  <mac address='$gen_mac_address'/>
  <ip address='0.13.0.1' netmask='255.255.255.0'>
  </ip>
</network>
_EOF_

uuid_val=`uuidgen`
generate_mac_address
echo "Using $uuid_val to generate ipoe-network.xml file"
echo "Using generated mac address $gen_mac_address for nni-uplinkbr"

cat > ipoe-network.xml << _EOF_
<network ipv6='yes'>
  <name>ipoe-network</name>
  <uuid>$uuid_val</uuid>
  <bridge name='ipoe-headbr' stp='off' delay='0'/>
  <mac address='$gen_mac_address'/>
  <ip address='0.12.0.1' netmask='255.255.255.0'>
  </ip>
  <ip family='ipv6' address='$IPOE_IPV6_PREFIX::0' prefix='64'>
  </ip>
</network>
_EOF_

sudo virsh net-list --all |grep ipoe-network || sudo virsh net-create ipoe-network.xml
sudo virsh net-list --all |grep nni-network || sudo virsh net-create nni-network.xml
ipoebr=`sudo virsh net-info ipoe-network|grep ipoe-headbr`
nnibr=`sudo virsh net-info nni-network|grep nni-uplinkbr`
if [[ -z $ipoebr || -z $nnibr ]]; then
  echo "Error creating $ipoebr or $nnibr"
  exit 1
fi
sudo ip link add dev nni-veth0 type veth peer name nni-veth1
sudo ip link set dev nni-veth0 dynamic off
sudo ip link set dev nni-veth1 dynamic off
sudo ip link set dev nni-veth0 up
sudo ip link set dev nni-veth1 up
sudo brctl addif nni-uplinkbr nni-veth0
echo "Adding ethernet port eth1 to nni-uplink bridge."
echo "Note: eth1 in headnode should be connected to NNI link in OLT"
if [ "$CORD_ENV" == "true" ]; then
sudo ifconfig eth1 up
sudo brctl addif nni-uplinkbr eth1
else
sudo ifconfig eth2 up
sudo brctl addif nni-uplinkbr eth2
fi

sudo ifconfig nni-uplinkbr up
echo "In two-node configuraiton, add eth2 to ipoe-headbr"
if [ "$CORD_TEST_SETUP" != "single" ]; then
sudo ifconfig eth2 up
sudo brctl addif ipoe-headbr eth2
fi


if [ "$CORD_ENV" == "true" ]; then
  sudo ovs-vsctl list-ports leaf1 |grep nni-veth1 || sudo ovs-vsctl add-port leaf1 nni-veth1
  ovsbr_leaf1=`sudo ovs-vsctl list-ports leaf1 |grep nni-veth1`
  if [[ -z ovsbr_leaf1 ]]; then
     echo "Either OVS bridge leaf1 does not exist or error in adding nni-veth1 port to OVS bridge leaf1"
    exit 1
  fi
else
  sudo brctl show ipoe-headbr| grep nni-veth1 || sudo brctl addif ipoe-headbr nni-veth1
  echo "Adding or already added nni-veth1 interface to ipoe-intbr"
fi 

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
