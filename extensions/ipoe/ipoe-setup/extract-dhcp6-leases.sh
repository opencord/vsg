#!/bin/bash
#**************************************************************/
#** File:         extract-dhcp6-leases.sh                     */
#** Contents:     Contains shell script to extract dhcp6 lease*/
#**               information captured by tcpdump.            */
#*************************************************************/
#
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
cd $IPOE_SETUP_DIR
source $WIDE_DHCP6_VARS

function extract_client_lease_info()
{
   echo "Extracting client_lease_info..."
   echo "DHCP6 Lease packet ****************"
   echo $lease_pkt
   echo "***********************************"
   time_stamp=`echo $lease_pkt|awk -F ' ' '{print $1" "$2}'|awk -F '.' '{ print $1}'`
   time=${time_stamp//-/\/} 
##
##
## Should use the command date -d @$time
##
   echo "Lease assignment time=$time"
   echo "Client hw addres=$client_hwaddr"
#
# Should use the following hw address to convert into
# Client DUID.
   echo "Client DUID=$client_hwaddr"
   duid=$DUID_PREFIX:${client_hwaddr:0:2}:${client_hwaddr:2:2}:${client_hwaddr:4:2}:${client_hwaddr:6:2}:${client_hwaddr:8:2}:${client_hwaddr:10:2}
   echo "duid:$duid"
   ctag_mod=$((16#${client_hwaddr:8:2}))
   stag_mod=$((16#${client_hwaddr:10:2}))
   echo "hostname :vcpe-$ctag_mod-$stag_mod"
  
   awk -F 'client-ID hwaddr' '{print $2}' $DHCP6_ADVT_PKTS_FILE| awk '{ print $3}'|sed 's/)//'|sort -u  >$DHCP6_CLIENTS_FILE
   server_id=`echo $lease_pkt|awk -F 'server-ID hwaddr/time' '{print $2}' |awk '{ print $5}'`
   echo "Server_id = $server_id"
   #echo "Complete the code to Extract other information...."
   addr=`echo $lease_pkt|awk -F 'IA_ADDR' '{print $2}' |awk '{ print $1}'`
   prefix=`echo $lease_pkt|awk -F 'IA_PD-prefix' '{print $2}' |awk '{ print $1}'`
   hardware=`echo $lease_pkt|awk -F '>' '{print $2}' |awk -F ',' '{ print $1}'|sed s/[[:space:]]//g`
   echo "addr=$addr ,prefix=$prefix,hardware=$hardware"   
}
function extract_lease_info()
{
   echo "Entering extract_lease_info..."
   i=0
   for client_hwaddr in "${dhcp6c_client_list[@]}"
   do
       i=$(( i+1 )) 
       echo "\nExtracting client lease for[$i]=$client_hwaddr\n"
#
# Verify that the DHCP release is not later than the DHCP6 advertisement
# packet    
       lease_remove=`tac $DHCP6_CAP_FILE|grep $client_hwaddr|grep -m 1 "dhcp6 release"`
       ts_remove=`echo $lease_remove|awk -F ' ' '{print $1" "$2}'`
       utc_remove=`date --date="$ts_remove" +%s`
# 
# Extract the last recorded dhcp6 lease packet for the client_hwaddr
#
      
       lease_pkt=`tac $DHCP6_ADVT_PKTS_FILE|grep -m 1 $client_hwaddr`
       ts_lease=`echo $lease_pkt|awk -F ' ' '{print $1" "$2}'`
       utc_lease=`date --date="$ts_lease" +%s`
       echo "ts_remove = $ts_remove utc_remove=$utc_remove..."
       echo "ts_lease = $ts_lease utc_lease=$utc_lease"
       if [ -z "$client_hwaddr" ]; then
           echo "Ignore this type"
       elif [ $client_hwaddr -eq 1 ]; then
           echo "Ignore this type"
       else
           if [ -z "$lease_remove" ] || (( $utc_lease >= $utc_remove ))
           then 
               extract_client_lease_info
               append_server_leases
           else
               echo "Lease removal date/time is more recent lease acquire time"
           fi 
       fi 
   done
}

function extract_dhcp6_client_list()
{
   echo "Entering extract_dhcp6_client_list..."
   awk -F 'client-ID hwaddr' '{print $2}' $DHCP6_ADVT_PKTS_FILE| awk '{ print $3}'|sed 's/)//'|sort -u  >$DHCP6_CLIENTS_FILE
   if [ -s "$DHCP6_CLIENTS_FILE" ]; then
      mapfile dhcp6c_client_list <$DHCP6_CLIENTS_FILE
      i=0
      for client_hwaddr in "${dhcp6c_client_list[@]}"
      do
         i=$(( i+1 )) 
         echo "Client HW address[$i]=$client_hwaddr"
      done
   else
      echo "No dhcp6 advertisment packet is found"
   fi
}

if [ $# -ne 1 ]; then
  echo "Usage $0 <dhcp6-capture file>"
  exit 1
fi

function append_server_leases(){
echo "Entering append_server_leases.. $hostname $vcpe_addr_hex "
cat >> $DHCP6_LEASES_FILE << _EOF_
{
hostname vcpe-$ctag_mod-$stag_mod
duid $duid
hardware $hardware
iaaddress $addr
iaprefix prefix $prefix
start-time $time
end-time infinity
}
_EOF_
} 

DHCP6_CAP_FILE=$1
DHCP6_ADVT_PKTS_FILE="/tmp/dhcp6-advt.log"
DHCP6_CLIENTS_FILE="/tmp/dhcp6-clients.txt"
DHCP6_LEASES_FILE="/tmp/server6.leases"
DHCP6_LEASES_FILEPATH="/var/lib/dhcpv6/server6.leases"
echo "Using $DHCP6_CAP_FILE to extract leases..."
grep 'dhcp6 advert' $DHCP6_CAP_FILE >$DHCP6_ADVT_PKTS_FILE
sudo rm -f $DHCP6_LEASES_FILE
sudo rm -f $DHCP6_LEASES_FILEPATH
extract_dhcp6_client_list
extract_lease_info
sudo cp $DHCP6_LEASES_FILE $DHCP6_LEASES_FILEPATH
