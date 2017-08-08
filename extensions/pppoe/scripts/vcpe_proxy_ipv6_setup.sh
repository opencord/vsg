
# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#!/bin/bash
#************************************************************/
#** File:         vcpe_proxy_ipv6_setup.sh                  */
#** Contents:     Contains shell script to setup VCPE IPv6  */
#**               environment and start apps                */
#************************************************************/
echo "vcpe_proxy_ipv6_setup.sh: BEGIN" >/tmp/ipv6.log
date >>/tmp/ipv6.log

echo "stop dnsmasq" >>/tmp/ipv6.log
sv down dnsmasq
sv down dnsmasq-safe
sleep 1

ps -fade|grep dnsmasq >>/tmp/ipv6.log

cd /home/ubuntu

tar -xvf ipv6.tar

echo "place conf files" >>/tmp/ipv6.log
mv radvd.conf /etc/
mv totd.conf /usr/local/etc/
mv tayga.conf /usr/local/etc/

ifconfig eth1 0.0.0.0
ifconfig eth1 inet6 add 2001:468:181:f100::1/64 up
sysctl -w net.ipv6.conf.all.forwarding=1

echo "Setup NAT64 Tayga" >>/tmp/ipv6.log
/home/ubuntu/tayga --mktun
sleep 1
ifconfig nat64 up
ifconfig nat64 mtu 1442
ip addr add 192.168.1.1 dev nat64
ip addr add 2001:db8:1::1 dev nat64
ip route add 192.168.255.0/24 dev nat64
ip route add 2000:ffff::/96 dev nat64
mkdir /var/db/
mkdir /var/db/tayga

ip6tables -A OUTPUT -p icmpv6 --icmpv6-type 1 -j DROP
ip6tables -A FORWARD -d 2001:468:181:f100:: -j DROP

echo "Start DHCPv6 radvd" >>/tmp/ipv6.log
/etc/init.d/radvd start &
sleep 1
echo "Start NAT64 Tayga" >>/tmp/ipv6.log
/home/ubuntu/tayga &
sleep 1
echo "Start DNS64 totd" >>/tmp/ipv6.log
/home/ubuntu/totd &

