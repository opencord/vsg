#!/bin/bash
#************************************************************/
#** File:         create-bind-conf.sh              */
#** Contents:     Contains shell script to create           */
#**               bind9 configuration file.                 */
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

cat > named.conf.options<< _EOF_
options {
        directory "/var/cache/bind";

        // If there is a firewall between you and nameservers you want
        // to talk to, you may need to fix the firewall to allow multiple
        // ports to talk.  See http://www.kb.cert.org/vuls/id/800113

        // If your ISP provided one or more IP addresses for stable 
        // nameservers, you probably want to use them as forwarders.  
        // Uncomment the following block, and insert the addresses replacing 
        // the all-0's placeholder.

         forwarders {
                $NAMESERVER;
         };

        //========================================================================
        // If BIND logs error messages about the root key being expired,
        // you will need to update your keys.  See https://www.isc.org/bind-keys
        //========================================================================
        dnssec-validation no;

        auth-nxdomain no;    # conform to RFC1035
        listen-on-v6 { any; };
     
        allow-query     { any; }; 
        dns64 $TAYGA_IPV6_PREFIX {};
};

_EOF_


time_end=`date`
echo "$0 Execution begin tim $time_begin"
echo "$0: Script execution completed successfully: $time_end"
