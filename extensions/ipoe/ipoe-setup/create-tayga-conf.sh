#!/bin/bash
#************************************************************/
#** File:         create-tayga-conf.sh              */
#** Contents:     Contains shell script to create           */
#**               tayga configuration file.                 */
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

if [ $# -ne 1 ]; then
  echo "Error...Missing/Invalid argument"
  echo "Usage: $0 <dhcp6_vars_file> "
  exit 1
fi

DHCP6_VARS_FILE=$1
if [ ! -f "$DHCP6_VARS_FILE" ]; then
  if [ ! -f $IPOE_SETUP_DIR/$DHCP6_VARS_FILE ]; then 
     echo "Missing DHCP6 configuration params file"
     exit 1
  else
    DHCP6_VARS_FILE="$IPOE_SETUP_DIR/$DHCP6_VARS_FILE"
  fi
fi
source $DHCP6_VARS_FILE

cat > tayga.conf<< _EOF_
#
# Sample configuration file for TAYGA 0.9.2
#
# Modify this to use your own addresses!!
#
tun-device nat64
#
# TAYGA's IPv4 address.  This is NOT your router's IPv4 address!  TAYGA
# requires its own address because it acts as an IPv4 and IPv6 router, and
# needs to be able to send ICMP messages.  TAYGA will also respond to ICMP
# echo requests (ping) at this address.
#
# This address can safely be located inside the dynamic-pool prefix.
#
ipv4-addr $TAYGA_ROUTER_IPV4_IP
#
# The NAT64 prefix.  The IPv4 address space is mapped into the IPv6 address
# space by prepending this prefix to the IPv4 address.  Using a /96 prefix is
# recommended in most situations, but all lengths specified in RFC 6052 are
# supported.
#
prefix $TAYGA_IPV6_PREFIX
#
# Dynamic pool prefix.  IPv6 hosts which send traffic through TAYGA (and do
# not correspond to a static map or an IPv4-translatable address in the NAT64
# prefix) will be assigned an IPv4 address from the dynamic pool.  Dynamic
# maps are valid for 124 minutes after the last matching packet is seen.
#
# If no unassigned addresses remain in the dynamic pool (or no dynamic pool is
# configured), packets from unknown IPv6 hosts will be rejected with an ICMP
# unreachable error.
#
dynamic-pool $TAYGA_POOL
#
# Persistent data storage directory.  The dynamic.map file, which saves the
# dynamic maps that are created from dynamic-pool, is stored in this 
# directory.  Omit if you do not need these maps to be persistent between
# instances of TAYGA.
#
data-dir /var/spool/tayga

_EOF_

time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
