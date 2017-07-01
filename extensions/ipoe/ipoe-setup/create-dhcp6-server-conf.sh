#!/bin/bash
#************************************************************/
#** File:         create-dhcp6-server-conf.sh               */
#** Contents:     Shell script to create wide-dhcp6-server  */
#**               configuration file.                       */
#************************************************************/
time_begin=`date`
echo "$0: Script execution begins: $time_begin"

function extract_stag_ctag() {
   echo "Entering extract_stag_ctag function.."
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

function append_vcpe_config(){
echo "Entering append_vcpe_config.. $stag_mod-$ctag_mod $vcpe_addr_hex "
if [ "$vcpe_auth_mode" == "auth-enable" ]; then
cat >> $DHCP6S_CONF_FILE << _EOF_
host vcpe-$stag_mod-$ctag_mod {
        duid $DUID_PREFIX:$MAC_PREFIX:$stag_mod_hex:$ctag_mod_hex;
        prefix $IPOE_IPV6_SUB_PREFIX::/48 infinity;
        address $IPOE_IPV6_PREFIX::$vcpe_addr_hex infinity;
        delayedkey vcpe-secret-key;
};

_EOF_
else

cat >> $DHCP6S_CONF_FILE << _EOF_
host vcpe-$stag_mod-$ctag_mod {
        duid $DUID_PREFIX:$MAC_PREFIX:$stag_mod_hex:$ctag_mod_hex;
        prefix $IPOE_IPV6_SUB_PREFIX::/48 infinity;
        address $IPOE_IPV6_PREFIX::$vcpe_addr_hex infinity;
};
_EOF_
fi
} 

function generate_vcpe_configs(){
  IFS=',' read -ra vcpe_names <<< "$VCPE_DOCKER_NAMES"
  let j=0
  for i in "${vcpe_names[@]}"
  do
     echo "Docker name[$j]: $i"
     IFS=':' read -ra vcpe_params <<< "$i"
     vcpe_dock_name="${vcpe_params[0]}"
     vcpe_auth_mode="${vcpe_params[1]}"
     echo "vcpe_dock_name = $vcpe_dock_name vcpe_auth_mode = $vcpe_auth_mode"
     VCPE_NAME=$vcpe_dock_name
     extract_stag_ctag
     ctag_mod=$(( $CTAG%250 ))
     stag_mod=$(( $STAG%250 ))
     stag_mod_hex=`printf '%02x' $stag_mod`
     ctag_mod_hex=`printf '%02x' $ctag_mod`
     echo "Appending configuration block for $vcpe_dock_name docker"
#
# Scheme 1:The last 16 bits of the IPv6 address to be assigned is
# calculated as 4096+ctag value. Note (4096= 1000H)
#
#
#     vcpe_addr=$(( 4096+$ctag_mod ))
#
# Schem 2: Last 16 bits of IPv6 address to be assigned is
# calculated by assigning stag value to the upper 8 bits and ctag to 
# the lower 8 bits.
#
     vcpe_addr=$(( $stag_mod*256 + $ctag_mod ))
     vcpe_addr_hex=`printf '%04x' $vcpe_addr`
     vcpe_addr_hex=`echo $vcpe_addr_hex| tr '[:lower:]' '[:upper:]'`
     append_vcpe_config  
  done
} 

WIDE_DHCP6_VARS="wide-dhcp6.vars"
#
# TODO: For some reason, the IPOE_SETUP_DIR is
# variable is set to /cord/ipoe-setup in 
# nodejs when this script is called. As a temporary work around, check
# existence of /home/ubuntu/ipoe/ipoe-setup/wide-dhcp6.vars file
# if it exists, source it.
#
if [ -f /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS ]; then
   source /home/ubuntu/ipoe/ipoe-setup/$WIDE_DHCP6_VARS
else
   source /cord/ipoe-setup/$WIDE_DHCP6_VARS
fi

if [ ! -z "$IPOE_SETUP_DIR" ]; then
  echo "Waring IPOE_SETUP_DIR is not set..using default value" >>/tmp/rest.log
  IPOE_SETUP_DIR="/home/ubuntu/ipoe/ipoe-setup"
fi

if [ "$CORD_ENV" == "true" ]; then
    IPOE_SETUP_DIR=/home/ubuntu/ipoe/ipoe-setup
else
  echo "Warning CORD_ENV is not set to true" >>/tmp/rest.log
  IPOE_SETUP_DIR=/cord/ipoe-setup
fi

if [ $# -ne 2 ]; then
  echo "Error...Missing argument"
  echo "Usage: $0 <dhcp6s_vars_file> <output_file_name>"
  exit 1
fi
DHCP6S_VARS_FILE=$1
DHCP6S_CONF_FILE=$2
if [ ! -f "$DHCP6S_VARS_FILE" ]; then
  if [ ! -f $IPOE_SETUP_DIR/$DHCP6S_VARS_FILE ]; then 
     echo "Missing DHCP6S configuration params file"
     exit 1
  else
    DHCP6S_VARS_FILE="$IPOE_SETUP_DIR/$DHCP6S_VARS_FILE"
  fi
fi
echo "Using $IPOE_SETUP_DIR as ipoe-setup dir" >>/tmp/rest.log
echo "Using $CORD_ENV cord_env setting" >>/tmp/rest.log
cd $IPOE_SETUP_DIR
work_dir=`pwd`
echo "Current working directory $work_dir" >>/tmp/rest.log
source $DHCP6S_VARS_FILE
echo "Generating DHCP6S conf file using params stored in $DHCP6S_VARS_FILE "
echo "******** Environment variables..." >>/tmp/rest.log
env >>/tmp/rest.log
echo "*********************************" >>/tmp/rest.log

echo "$dom_name ....$domain_name_servers...$IPOE_IPV6_PREFIX..." >>/tmp/rest.log
cat > $DHCP6S_CONF_FILE << _EOF_
#******************************************************/
#  Configuration file for wide-dhcp6-server           */
#  Generated on : $time_begin        */
#******************************************************/
#
# The following is an example configuration which provides a DNS server
# address to every client which sends the request thru the
# designated interface.

option domain-name "$dom_name";
option domain-name-servers $domain_name_servers; 
option ntp-servers $ntp_servers;
option sip-server-address $sip_server_address;

# The following is an example configuration which provides an IPv6 address
# from an address pool (fd64:8D64:AF0c:1::1500-2000) with a lease time of 3600
# seconds to any client attached to the eth1 interface. Note that you have
# to send router advertisements on eth1, i.e. run rtadvd(8) on that interface.
# Otherwise a client cannot know the prefix-length and the default router.
# If you want to prevent stateless address configuration via RA, please 
# set the autonomous-flag to OFF in your RA configuration.
# The following configuration is needed, only if we want to support
# SLAAC on eth1 in addition to providing stateful address assignment

interface $DHCP6S_IPOE_INTF {
        address-pool pool1 3600;
};

pool pool1 {
        range $IPOE_IPV6_PREFIX::$IPOE_IPV6_ADDR_LOW to $IPOE_IPV6_PREFIX::$IPOE_IPV6_ADDR_HIGH;
};

# If a shared secret was to be configured in both the server and the client
# for DHCPv6 authentication, it would be specified in this file as follows:
# Secret should be encoded using base-64 generator. For example, feed the 
# chosen passwd (fj-ipoe-passwd) to any one of the online base-64 password
# generator and copy the generated base64 password text string into the
# secret key below.

keyinfo vcpe-secret-key {
     realm "$dom_name";
     keyid 1;
     secret "$secret_key";
};


_EOF_
echo "Fixed part of dhcp6 server config generated.."
echo "*********************************************"
cat $DHCP6S_CONF_FILE
echo "*********************************************"
echo "Adding vcpe address block.."

generate_vcpe_configs

time_end=`date`
echo "$0 Script execution begin tim $time_begin" 
echo "$0: Script execution completed successfully: $time_end"
