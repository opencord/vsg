#!/bin/bash
#************************************************************/
#** File:         create-dhcp6-client-conf.sh               */
#** Contents:     Shell script to create wide-dhcp6-client  */
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

function create_conf_file_wan_lan_block() {

cat > $dhcp6c_conf_file << _EOF_
#******************************************************/
#  Configuration file for wide-dhcp6-client           */
#  Generated on : $time_begin        */
#******************************************************/
#
# wide-dhpc6c configuration file: it is based on the assumption that the 
# address for the DHCP6C_WAN_INTF is assigned by DHCP6 server.
# The address for the DHCP6C_LAN_INTF is assigned based on the
# prefix value derived by the address assigned by the DHCP6 server.
# 

# If a shared secret was to be configured in both the client and the server
# for DHCPv6 authentication, it would be specified in this file as follows:

# The following configuration params define the interaction with DHCP6  
# server

interface $DHCP6C_WAN_INTF {
       send ia-na 0;
       send ia-pd 0;
       send rapid-commit;
       script "/etc/wide-dhcpv6/$WIDE_DHCP6C_SCRIPT";
       request domain-name;
_EOF_

#
# Add the appropriate commands for each server address to be
# requested by the DHCP6 client.
#
IFS=',' read -ra request_params <<< $DHCP6C_REQUEST_PARAMS 
   for param in "${request_params[@]}"
   do
       if [ "$param" == "domain-name-servers" ]; then
cat >> $dhcp6c_conf_file << _EOF_
       request domain-name-servers;
_EOF_
       fi
       if [ "$param" == "ntp-servers" ]; then
cat >> $dhcp6c_conf_file << _EOF_
       request ntp-servers;
_EOF_
       fi
       if [ "$param" == "sip-server-address" ]; then
cat >> $dhcp6c_conf_file << _EOF_
       request sip-server-address;
_EOF_
       fi
   done

if [ "$vcpe_auth_mode" == "auth-enable" ]; then
cat >> $dhcp6c_conf_file << _EOF_
       send authentication vcpe-secret-auth;
_EOF_
fi
#
# Close out the dhcp6c WAN_INTF block by writing out the right paranthesis.
# and the LAN_INTF related items.
#
#
# The LAN_INTF IP address is derived from the IPv6 SUB_PREFIX+sla-id value
# For example, the IPOE_IPV6_SUB_PREFIX=FD64:8D64:AF0C/48
# and the sla-id=86, the prefix for the LAN_INTF and the subnet (i.e, ONU) 
# attached to the subnet would be FD64:8D64:AF0C:86::/64. The interface 
# IPv6 address assigned to the LAN_INTF would be
# IPOE_IPV6_SUB_PREFIX:<sla-id>:<EUI-64>
# Assume that the HW MAC address for the LAN_INTF is 
# 00:0E:10:00:22:34, the EUI-64 would be 00:0E:10:FF:FE:00:22:34.
# therefore, the IPv6 address assigned by the wide-dhcp6-client would
# be, 
#  FD64:8D64:AF0C:86:000E:10FF:FE00:2234
#
#
# sla_id_val is 16 bit number and the value is composed with
# stag value assigned to the upper 8 bits and ctag value assigned
# to the lower eight bits. 
# For example, if stag=34, ctag=134 then the sla_id_val would
# be 2286 (hex)
# 
sla_id_val=$(( $stag_mod*256 + $ctag_mod ))

cat >> $dhcp6c_conf_file << _EOF_
};

id-assoc na {
};

#Note: sla-id should be set equal to ctag value
# derived from vcpe docker name.
# The LAN_INTF IPv6 address will be configured by the
# WIDE_DHCP6C_SCRIPT as follows:
# IPOE_IPV6_SUB_PREFIX:<sla-id>::1
id-assoc pd {
        prefix-interface $DHCP6C_LAN_INTF {
                sla-id $sla_id_val;
                ifid 1;
                sla-len 16;
        };
};

_EOF_

}

function create_dhcp6c_config_file() {

echo "Entering create_dhcp6c_config_file.. $stag_mod-$ctag_mod $vcpe_addr_hex "
dhcp6c_conf_file="dhcp6c-$stag_mod-$ctag_mod.conf"
create_conf_file_wan_lan_block
if [ "$vcpe_auth_mode" == "auth-enable" ]; then

cat >> $dhcp6c_conf_file << _EOF_
# If a shared secret was to be configured in both the client and the server
# for DHCPv6 authentication, it would be specified in this file as follows:

keyinfo vcpe-secret-key {
     realm "$dom_name";
     keyid 1;
     secret "$secret_key";
};
authentication vcpe-secret-auth {
         protocol delayed;
};

_EOF_
fi

}

function create_radvd_config_file(){
 if [ "$vcpe_client_type" == "windows" ]; then
    radvd_raw_script="radvd-windows.raw"
 else
    radvd_raw_script="radvd-dibbler.raw"
 fi
 radvd_script_file="radvd-$stag_mod-$ctag_mod.sh"
 echo "Using $radvd_raw_script as raw radvd_script file"
 cat $IPOE_SETUP_DIR/$radvd_raw_script|sed -e "s/\@\@dhcp6c_lan_intf\@\@/$DHCP6C_LAN_INTF/g" >$IPOE_SETUP_DIR/$radvd_script_file
 sed -i -e "s/\@\@dhcp6c_wan_intf\@\@/$DHCP6C_WAN_INTF/g" $IPOE_SETUP_DIR/$radvd_script_file
 chmod 755 $IPOE_SETUP_DIR/$radvd_script_file
}

function generate_dhcp6c_config_for_vcpe_dockers(){
  IFS=',' read -ra vcpe_names <<< "$VCPE_DOCKER_NAMES"
  let j=0
  for i in "${vcpe_names[@]}"
  do
     echo "Docker name[$j]: $i"
     IFS=':' read -ra vcpe_params <<< "$i"
     vcpe_dock_name="${vcpe_params[0]}"
     vcpe_auth_mode="${vcpe_params[1]}"
     vcpe_client_type="${vcpe_params[2]}"
     echo "vcpe_dock_name = $vcpe_dock_name vcpe_auth_mode = $vcpe_auth_mode vcpe_client_type = $vcpe_client_type"
     VCPE_NAME=$vcpe_dock_name
     extract_stag_ctag
     ctag_mod=$(( $CTAG%250 ))
     stag_mod=$(( $STAG%250 ))
     stag_mod_hex=`printf '%02x' $stag_mod`
     ctag_mod_hex=`printf '%02x' $ctag_mod`
     echo "Generating dhcp6c config file for $vcpe_dock_name docker"
     create_dhcp6c_config_file  
     create_radvd_config_file
  done
} 
if [ $# -ne 1 ]; then
  echo "Usage $0 <wide-dhcp6-vars];"
  exit 1
fi

WIDE_DHCP6_VARS=$1

if [ -z "$WIDE_DHCP6_VARS" ]; then
    WIDE_DHCP6_VARS="wide-dhcp6.vars"
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

DHCP6_VARS_FILE=$IPOE_SETUP_DIR/$WIDE_DHCP6_VARS

if [ -z "$wide_dhcp6c_raw_script" ]; then
   wide_dhcp6c_raw_script="wide-dhcp6c-script.raw"
   echo "Using $wide_dhcp6c_raw_script as unprocessed wide-dhcpc6c-script.sh"
fi

source $DHCP6_VARS_FILE

if [ -z "$radvd_raw_script" ]; then
   radvd_raw_script="radvd-script.raw"
   echo "Using $radvd_raw_script as unprocessed radvd-script.sh"
fi

if [ -z "$RADVD_SCRIPT" ]; then
   RADVD_SCRIPT="radvd-script.sh"
   echo "Using $radvd_raw_script as unprocessed radvd-script.sh"
fi

echo "Generating DHCP6C conf file using params stored in $DHCP6_VARS_FILE "

generate_dhcp6c_config_for_vcpe_dockers

echo "Cleaning up wide-dhcp6c_raw_script..."
cat $IPOE_SETUP_DIR/$wide_dhcp6c_raw_script|sed -e "s/\@\@ipoe_ipv6_sub_prefix\@\@/$IPOE_IPV6_SUB_PREFIX/g" >$WIDE_DHCP6C_SCRIPT
echo $DHCP6C_LAN_INTF
sed -i -e "s/\@\@dhcp6c_lan_intf\@\@/$DHCP6C_LAN_INTF/g" $WIDE_DHCP6C_SCRIPT
sed -i -e "s/\@\@dhcp6c_wan_intf\@\@/$DHCP6C_WAN_INTF/g" $WIDE_DHCP6C_SCRIPT
chmod 755 $WIDE_DHCP6C_SCRIPT
#cat $IPOE_SETUP_DIR/$radvd_raw_script|sed -e "s/\@\@dhcp6c_lan_intf\@\@/$DHCP6C_LAN_INTF/g" >$RADVD_SCRIPT
#chmod 755 $RADVD_SCRIPT

time_end=`date`
echo "$0 Script execution begin tim $time_begin" 
echo "$0: Script execution completed successfully: $time_end"

