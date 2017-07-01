#!/bin/bash
#***************************************************************/
#** File:         setup-dibbler-client.sh                        */
#** Contents:     Contains shell script to setup env for       */
#**               running dibbler client in onu-sim VM.        */
#***************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

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

if [ $# -ne 1 ]; then 
  echo "Usage $0 <vcpe-name> "
  echo "Example: setup-dibbler-client.sh vcpe-34-134"
  exit 1
fi
TARGET_DOCKER_NAME=$1
extract_stag_ctag
echo "Setting up onusim-server to connect to $TARGET_DOCKER_NAME docker"
echo "Using stag=$stag and ctag=$ctag"

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
sudo ifconfig eth1 up
sudo ip link add link eth1 name eth1.$stag type vlan id $stag
sudo ip link set dev eth1.$stag dynamic off
sudo ip link set dev eth1.$stag up
sudo ip link add link eth1.$stag name eth1.$stag.$ctag type vlan id $ctag
sudo ip link set dev eth1.$stag.$ctag dynamic off
sudo ip link set dev eth1.$stag.$ctag up

echo "Install dibbler-client ..."
cd $IPOE_SETUP_DIR
cp $IPOE_SETUP_DIR/dibbler-client_0.7.3-1.3_amd64.deb /tmp
cd /tmp
sudo dpkg -i dibbler-client_0.7.3-1.3_amd64.deb
echo "Creating client.conf file"
   
cat > client.conf<< _EOF_
# Defaults for dibbler-client.
# installed at /etc/dibbler/client.conf by the maintainer scripts

# 8 (Debug) is most verbose. 7 (Info) is usually the best option
log-level 7

# To perform stateless (i.e. options only) configuration, uncomment
# this line below and remove any "ia" keywords from interface definitions
stateless
script "/etc/dibbler/setup-ipv6env.sh"
iface eth1.$stag.$ctag {
    option dns-server
    option domain
    option ntp-server
#    option sip-server
#    option sip-domain
}
_EOF_


cat > setup-ipv6env.sh << _EOF_
#!/bin/bash

ipv6_dns=\`cat /etc/resolv.conf|grep nameserver|grep ":"| awk '{ print \$2 }'\`
if [ ! -z "\$ipv6_dns" ]; then
  ipv6_sub_up=\`echo \$ipv6_dns|awk -F':' '{print \$1":"\$2":"\$3":"}'\`
  ipv6_sub_tr=\`echo \$ipv6_sub_up|tr "[:upper:]" "[:lower:]"\`
  echo "Translated ipv6_sub \$ipv6_sub_tr "
  ipv6_addr=\`ifconfig eth1.$stag.$ctag|grep \$ipv6_sub_tr|awk '{print \$3}'\`  
  if [ ! -z "\$ipv6_addr" ]; then
     echo "Deleting IPv6 address \$ipv6_addr assigned to eth1.$stag.$ctag"
     sudo -E ip -6 addr del \$ipv6_addr dev eth1.$stag.$ctag
  fi
  subnet_prefix=\`ip -6 route show|grep \$ipv6_sub_tr|awk '{print \$1}'|grep \$ipv6_sub_tr\`
  if [ ! -z "\$subnet_prefix" ]; then
    echo "Deleting subnet route \$subnet_prefix.."
    sudo -E ip -6 route del \$subnet_prefix dev eth1.$stag.$ctag
  fi
  default_target=\`echo \$subnet_prefix|awk -F':' '{print \$1":"\$2":"\$3":"\$4"::1"}'\`
  if [ ! -z "\$default_target" ]; then 
     echo "Deleting default route \$default_target"
     sudo -E ip -6 route del ::/0 via \$default_target dev eth1.$stag.$ctag 
 fi
fi 

echo "Waiting for IPv6 address assignment for  eth1.$stag.$ctag" 
for ntime in {1..10}
do
   lan_intf_prefix=\`ifconfig eth1.$stag.$ctag|grep Global|awk '{print \$3}'|awk -F':' '{print \$1":"\$2":"\$3":"\$4":"}'\`
   newsub_prefix=\`ifconfig eth1.$stag.$ctag|grep Global|awk '{print \$3}'|awk -F':' '{print \$1":"\$2":"\$3}'\`
  if [ ! -z "\$lan_intf_prefix" ]; then
    break
  fi 
  sleep 6 
  echo "Waiting for global IPv6 address for LAN _Intf count: \$ntime" 
done

if [ -z "\$lan_intf_prefix" ]; then
  echo "ERROR...Global address not assigned to eth1.$stag.$ctag" 
  exit 1
fi  
echo "Adding default IPv6 route to send everything via eth1.$stag.$ctag"
#sudo ip -f inet6 route add ::/0 via \$lan_intf_prefix:1 dev eth1.$stag.$ctag  
sudo -E ip -6 roue del default
sudo -E route -A inet6 add default gw \$lan_intf_prefix:1
sudo ip -6 route show
DNS_SERVER_ADDR="\$newsub_prefix:1::1"
echo "Adding $DNS_SERVER_ADDR to resolv.conf"
sudo -E bash -c "echo nameserver \$DNS_SERVER_ADDR > /etc/resolv.conf"
_EOF_

cat > dibbler-monitor.sh << _EOF_
#!/bin/bash
echo "Entering Monitor loop"
while true; do
  ts=\`date\`
  count=\`ifconfig eth1.$stag.$ctag|grep Global|wc -l\`
  if [[ \$count > 1 ]]; then
    echo "\$ts:::::Calling setup-ipv6env.sh" >>/tmp/dibmon.log
    /etc/dibbler/setup-ipv6env.sh >>/tmp/dibmon.log
    ifconfig eth1.$stag.$ctag >>/tmp/dibmon.log
    ip -6 route show >>/tmp/dibmon.log
   echo "ipv6 env rest for the new prefix"
  fi
#  echo "\$ts:::In loop checking again.."
  sleep 15
done
_EOF_
chmod +x /tmp/dibbler-monitor.sh
sudo cp /tmp/dibbler-monitor.sh /etc/dibbler
chmod +x /tmp/setup-ipv6env.sh
sudo cp /tmp/setup-ipv6env.sh /etc/dibbler

sudo cp client.conf /etc/dibbler
sudo /usr/sbin/dibbler-client stop
sleep 1
sudo /usr/sbin/dibbler-client start
sleep 1
sudo /etc/dibbler/setup-ipv6env.sh
sleep 1
echo "dibbler-monitor.sh started"
sudo nohup /etc/dibbler/dibbler-monitor.sh 2>&1 &

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
