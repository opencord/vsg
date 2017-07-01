This Readme file contains information about the Rest APIs about the Rest APIs supported in the NTT-East IPoE IPv6 PoC implementation.

# REST API Specification
==================================

IPoE IPv6 PoC system can be configured, monitored and controlled through REST API. 
The REST API can be accessed using the fixed IPv4 address assigned to eth1 interface of the IPoE server VM or the IPv4 address assigned to the ipoe-intbr in the vSG VM.

For example, if the IPOE\_MGMT\_SUBNET\_PREFIX is configured as "172.30.100.0" in the wide-dhcp6.vars file, then the IPv4 address for eth1 address in the IPoE Server would be 172.30.100.1 and the "ipoe-intbr" would be 172.30.100.5. Assume that the IPOE\_MGMT\_PORT is configured as 9020.

To retrieve or modify IPoE IPv6 System related configuration such as the variables defined in "wide-dhcp6.vars" file or the DHCP6 server related configuration, the REST API should be accessed through the IP address 172.30.100.1:9020.

To retrieve or modify IPoE IPv6 DHCP6 client related configuration or retrieve DHCP6 client status, the REST API should be accessed through the IP address 172.30.100.5:9020.

In the REST API description, the Target Address is denoted as `<ipoe-server-ip>:<port-num>` or `<vsg-server-ip>:<port-num>` to identify the target IP address and port number that should be used to access the REST API.

## Managing System Variables
-------------------------

### Retrieve IPoE System Variables

**URL Path**: `/ipoe/systemVars`

**Target Address**: `<ipoe-server-ip>:<port-num>`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
None
```
**Response Data:**
```
 {
   "CORD_ENV":"true",
   "CORD_TEST_SETUP":"single",
   "IPOE_MGMT_SUBNET_PREFIX":"172.30.100",
   "IPOE_MGMT_PORT":9020,
   "IPOE_IPV6_SUB_PREFIX":"FD64:8D64:AF0C",
   "IPOE_IPV6_PREFIX":"FD64:8D64:AF0C:1",
   "dom_name":"fj-ipoe.net",
   "domain_name_servers":"2001:4860:4860::8888",
   "ntp_servers":"FD64:8D64:AF0C:1::1057",
   "sip_server_address":"FD64:8D64:AF0C:1::1058",
   "secret_key":"ZmotaXBvZS1wYXNzd2Q=",
   "DHCP6S_IPOE_INTF":"eth1",
   "IPOE_IPV6_ADDR_LOW":1500,
   "IPOE_IPV6_ADDR_HIGH":2000,
   "DUID_PREFIX":"00:03:00:01",
   "MAC_PREFIX":"00:0E:10:00",
   "VCPE_DOCKER_NAMES":"vcpe-34-134:auth-enable,vcpe-34-156:auth-enable,vcpe-36-160:auth-enable,vcpe-36-161:auth-disable",
   "DHCP6C_WAN_INTF":"eth2",
   "DHCP6C_LAN_INTF":"eth1",
   "wide_dhcp6c_raw_script":"wide-dhcp6c-script.raw",
   "WIDE_DHCP6C_SCRIPT":"wide-dhcp6c-script.sh",
   "DHCP6C_REQUEST_PARAMS":"domain-name-servers,ntp-servers",
   "NAMESERVER": "8.8.8.8",
   "TAYGA_POOL": "172.16.254.0/24",
   "TAYGA_ROUTER_IPV4_IP": "172.16.254.1",
   "TAYGA_ROUTER_IPV6_IP": "4000:0:0:2::1",
   "TAYGA_IPV6_PREFIX": "4000:0:0:2:eeee::/96"
 }
```
**Description:**

> Returns system wide parameters used by the DHCP6 server and DHCP6  Client.

**Additional Notes:**

> *Parameter Name*: N/A
>
> *Description& Handling*: Values displayed in the response are retrieved from the file wide-dhpc6.vars stored under the directory /home/ubuntu/ipoe/ipoe-setup in the head node (same as the mounted directory /cord/ipoe/ipoe-setup in IPoE Server VM).

### Update IPoE System Variables

**URL Path:** `/ipoe/systemVars`

**Target Address**: `<ipoe-server-ip>:9020`

**Parameter:** `[option]`
```
 {
   "IPOE_IPV6_SUB_PREFIX":"FD64:8D64:AF0C",
   "IPOE_IPV6_PREFIX":"FD64:8D64:AF0C:1",
   "dom_name":"fj-ipoe-ipv6.net",
   "domain_name_servers":"2001:4860:4860:8888",
   "ntp_servers":"2001:4860:4860::1057",
   "sip_server_address":"2001:4860:4860::1058",
   "secret_key":"ZmotaXYsyP1wYXNzd2Q=",
   "IPOE_IPV6_ADDR_LOW":1500,
   "IPOE_IPV6_ADDR_HIGH":2000,
   "DUID_PREFIX":"00:03:00:01",
   "MAC_PREFIX":"00:0E:10:00",
   "VCPE_DOCKER_NAMES":"vcpe-34-134:auth-enable,vcpe-34-156:auth-enable,vcpe-36-160:auth-enable,vcpe-36-161:auth-disable",
   "wide_dhcp6c_raw_script":"wide-dhcp6c-script.raw",
   "WIDE_DHCP6C_SCRIPT":"wide-dhcp6c-script.sh",
   "DHCP6C_REQUEST_PARAMS":"domain-name-servers,ntp-servers,sip-server-address",
   "TAYGA_IPV6_PREFIX":"4000:0:0:2:eeee::/96",
   "TAYGA_ROUTER_IPV6_IP":"4000:0:0:2::1",
   "TAYGA_ROUTER_IPV4_IP":"172.16.254.1",
   "TAYGA_POOL":"172.16.254.0/24",
   "NAMESERVER":"8.8.8.8"
 }
```
**Method:** `PUT`

**Request Data:**
```
"TAYGA_IPV6_PREFIX=4000:0:0:2:eeee::/96&TAYGA_ROUTER_IPV6_IP=4000:0:0:2::1&TAYGA_ROUTER_IPV4_IP=172.16.254.1&NAMESERVER=8.8.8.8&VCPE_DOCKER_NAMES=vcpe-34-156:auth-enable:dibbler,vcpe-34-134:auth-enable:dibbler&IPOE_IPV6_ADDR_LOW=1501"

```
**Response Data:**
```
None or Error Response
```
**Description:**

> Update one or more IPoE System variables. Note that some of IPoE system parameters such as CORD\_ENV, IPOE\_MGMT\_SUBNET\_PREFIX, DHCP6S\_IPOE\_INTF, DHCP6C\_WAN\_INTF and DHCP6C\_LAN\_INTF cannot be updated through REST API. 
Any change in the values of these parameters would require reinstallation of IPoE server VM and compute-node VM and vSG Server VM. 
So, it is recommended that these variables are updated only prior to the installation of the IPoE IPv6 system packages.

**Additional Notes:**

>*Parameter Name:* IPOE\_IPV6\_PREFIX

>*Description:* The IPOE\_IPV6\_PREFIX should use the value defined by IPOE\_IPV6\_SUB\_PREFIX.

Managing DHCP6 Server
---------------------

### Retrieve DHCP6S Configuration

**URL Path:** `/ipoe/dhcp6s`

**Target Address:** `<ipoe-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=config"
```
**Response Data: **
```
 {
   "config_file_name":"dhcp6s.conf",
   "config_file_contents": [{
     "domain-name":"fj-ipoe.net",
     "domain-name-servers":"2001:4860:4860::8888",
     "ntp-servers:"FD64:8D64:AF0C:1::1057",
     "sip-server-address":"FD64:8D64:AF0C:1::1058",
     "interface":{
       "value":"eth1",
       "address-pool":"3600"
     },
     "pool": {
       "ipoe_ipv6_addr_low":"FD64:8D64:AF0C:1::1500",
       "ipoe_ipv6_addr_high":"FD64:8D64:AF0C:1::2000"
     },
     "vcpe-secret-key":{
       "realm":"fj-ipoe.net",
       "keyid": 1,
       "secret":"ZmotaXBvZS1wYXNzd2Q="
     },
     "vcpe-34-134": {
       "duid":"00:03:00:01:00:0E:10:00:22:86",
       "prefix":"FD64:8D64:AF0C::/48",
       "address":"FD64:8D64:AF0C:1::2286",
       "delayedkey":"vcpe-secret-key",
     },
     "vcpe-34-156": {
       "duid":"00:03:00:01:00:0E:10:00:22:9c",
       "prefix":"FD64:8D64:AF0C::/48",
       "address":"FD64:8D64:AF0C:1::229C",
       "delayedkey":"vcpe-secret-key",
     },
     "vcpe-36-160 {
       "duid":"00:03:00:01:00:0E:10:00:24:a0",
       "prefix":"FD64:8D64:AF0C::/48",
       "address":"FD64:8D64:AF0C:1::24A0",
       "delayedkey":"vcpe-secret-key",
     },
     "vcpe-36-161": {
       "duid":"00:03:00:01:00:0E:10:00:24:a1",
       "prefix":"FD64:8D64:AF0C::/48",
       "address":"FD64:8D64:AF0C:1::24A1",
     }
   }]
 }
```
**Description:**

> Retrieves the name and the contents of the configuration file used by the DHCP6 server. 
The configuration file used by the DHCP6 server is generated by "create-dhcp-server-conf.sh" script using the IPoE system variables defined in the "wide-dhcp6.vars" file.

**Additional Notes:**

>*Parameter:* N/A

>*Description& Handling:* Each "host" configuration block (e.g., vcpe-34-134) corresponds to the IPv6 address, prefix to be assigned to one of the DHCP clients. The DHCP client is identified by the name listed in the IPoE system variable "VCPE\_DOCKER\_NAMES".

>*Parameter:* vcpe-xxx-yyy

>Description&Handling: The IPv6 address to be assigned to a DHCP6 client is constructed as :`IPOE_IPV6_PREFIX::<STAG>*256+<CTAG>`. 
The IPOE\_IPV6\_PREFIX is defined in the IPOE system variables file. 
The STAG and CTAG values are extracted from the VCPE docker name (e.g, vcpe-34-134).

### Retrieve DHCP6 Server Status

**URL Path:** `/ipoe/dhcp6s`

**Target Address:** `<ipoe-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=status"
```
**Response Data:**
```
 {
   "status": "Running"
 }
 Or
 {
   "status": "Stopped"
 }
```
**Description:**

> Returns the status of DHCP6 server

### Retrieve DHCP6 Server Leases

**URL Path:** `/ipoe/dhcp6s`

**Target Address:** `<ipoe-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=leases"
```
**Response Data: **
```
 {
   "host":[
   {
     "hostname": "vcpe-34-134",
     "duid": "00:03:00:01:00:0E:10:00:22:86",
     "hardware": "00:00E:10:20:30:40",
     "iaaddress": "FD64:8D64:AF0C:1::2286",
     "iaprefix": "prefix FD64:8D64:AF0C::/48"
     "start-time": "2017/11/17 10:30:08",
     "end-time": "infinity",
   },
   {
     "hostname": "vcpe-34-156",
     "duid": "00:03:00:01:00:0E:10:00:22:9c",
     "hardware": "00:00E:10:21:31:41",
     "iaaddress": "FD64:8D64:AF0C:1::229C",
     "iaprefix": "prefix FD64:8D64:AF0C::/48"
     "start-time": "2017/11/16 23:10:45",
     "end-time": "infinity",
   },]
 }
```
**Description:**

> Retrieves the information about the active leases (i.e., IPv6 addresses assigned) to the DHCP6 client running in VCPE docker instances. 
This information is retrieved from the file /var/lib/dhcpv6/server6.leases.

**Additional Notes:**

>*Parameter:* Hardware

>*Description&Handling:* Refers to the MAC address of the DHCP6 client.

### Stop/Start/Restart DHCP6 Server

**URL Path:** `/ipoe/dhcp6s`

**Target Address:** `<ipoe-server-ip>:9020`

**Parameter:** `None`

**Method:** `POST`

**Request Data:**
```
"operation=start"
```
**Response Data**:
```
 None
```
**Description:**

> Command to start, stop or restart the DHCP6 server.

**Additional Notes:**

>*Parameter:* operation

>*Description&Handling:* By setting the parameter operation="stop" or operation="restart", the DHCP6 server can be stopped or restarted.

Managing DHCP6 Client
---------------------

### Retrieve DHCP6 Client Configuration

**URL Path:** `/ipoe/dhcp6c`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=config&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "generated_conf_file": "dhcp6c-34-134.conf",
   "running_config_file_name": "dhcp6c.conf",
   "client_duid": "00:03:00:01:00:0E:10:00:22:86",
   "running_config_file_contents": [{
     "interface":{
       "value":"eth2",
       "domain-name": true,
       "domain-name-servers": true,
       "ntp-servers": true,
       "authentication": true
     },
     "prefix-interface": {
       "value":"eth1",
       "sla-id": "8838"
     },
     "vcpe-secret-key": {
       "realm": "fj-ipoe.net",
       "keyid": 1,
       "secret": "ZmotaXBvZS1wYXNzd2Q="
     }
   }]
 }
 Or
 {
   "Docker is not running or IPv6 is not enabled"
 }
```
**Description:**

> Retrieve configuration data from the DHCP6 client running inside the docker instance specified by the parameter "docker\_name".

**Additional Notes:**

>*Parameter:* docker-name

>*Description&Handling:* The name of the VCPE docker where the DHCP6 client is running.

### Retrieve DHCP6 Client Status

**URL Path:** `/ipoe/dhcp6c`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=status&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "status": "Running"
 }
 Or
 {
   "status": "Stopped"
 }
 Or
 {
   "status": "Docker does not exist or IPv6 is not enabled"
 }
```
**Description:**

> Retrieve DHCP client status running inside the docker instance matching the name provided by the "docker\_name" parameter.

**Additional Notes:**

>*Parameter:* status

>*Description&Handling:* If the docker instance matching the "docker\_name" provided in the request has not been created or if IPv6 is not enabled in the docker, the response "Docker does not exist or IPv6 is not enabled" is returned.

### Retrieve DHCP6 Client Lease Information

**URL Path:** `/ipoe/dhcp6c`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=leases&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "hardware": "00:00E:10:20:30:40",
   "iaaddress": "FD64:8D64:AF0C:1::2286",
   "iaprefix": "FD64:8D64:AF0C::/48"
   "start-time": "2017/17/11 10:30:08",
   "end-time": "infinity",
   "domain-name-servers": "2001:4860:4860::8888"
   "ntp-servers": "FD64:8D64:AF0C:1::1057",
 }
 Or
 {
   "No Lease information available"
 }
 Or
 {
   "Docker is not running or IPv6 is not enabled"
 }
```
**Description:**

> Retrieve the lease information acquired by the DHCP6 client running inside the docker instance.

**Additional Notes:**

>*Parameter:* iaaddress

>*Description&Handling:* The iaaddress indicates the IPv6 address assigned by the DHCP6 server. 
This address is assigned to the interface (eth2) through which the DHCP6 client sent the IPv6 solicitation request.

>*Parameter:* iaprefix

>*Description&Handling:* The iaprefix value to propagated to the Client PC as part of the router advertisements generated by the "radvd" program.

### Enable/Disable DHCP6 Client

**URL Path:** `/ipoe/dhcp6c`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `POST`

**Request Data:**
```
"operation=enable&docker-name=vcpe-34-134"
Or
"operation=disable&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "DHCP6 Client operation enabled"
 }
 Or
 {
   "Docker does not exist"
 }
 Or
 {
   "DHCP6 Client operation disabled"
 }
```
**Description:**

> Command to enable or disable DHCP6 client operation. 
If enabled, the DHCP6 client program is automatically stopped and IPv6 packets would be processed after the DHCP6 client receives the IPv6 address from the DHCP6 server. 
This scope of this command depends on the value assigned to the "docker-name".

**Additional Notes:**

>*Parameter:* operation

>*Description&Handling:* If operation=enable, the DHCP6 client would be started. 
If operation=disable then DHCP6 client would be stopped and vCPE docker will start forwarding IPv4 packets.

>*Parameter:* docker-name

>*Description-name:* Should use the format, `vcpe-<stag>-<ctag>`. 
If docker-name=all, then the operation is applied to all docker instances.

### Stop/Start/Restart DHCP6 Client

**URL Path:** `/ipoe/dhcp6c`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `POST`

**Request Data:**
```
"operation=start&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "Success"
 }
 Or
 {
   "Docker does not exist"
 }
```
**Description:**

> Command to start, stop or restart the DHCP6 client. This scope of this command depends on the value assigned to the "docker-name". 
Since the radvd/dibbler-server program depends on IPv6 prefix/DNS server address information acquired by the client, start/stop/restart operation on DHCP6 client would stop "radvd" and "dibbler-server" programs and will be automatically started by the wide-dhcp6-client-script.sh script is executed by the DHCP6 client after it receives the IPv6 address/prefix information from the server.

**Additional Notes**:

> *Parameter:* operation
>
> *Description&Handling:* By setting the parameter operation="stop" or operation="restart", the DHCP6 client can be stopped or restarted.
>
> *Parameter:* docker-name

>*Description&Handling:* Docker Name should be of the form `"vcpe-<stag>-<ctag>"` or `"all"`.
>
>```
>  Parameter Name       Description & Handling (Information Source)
>  -------------------- -------------------------------------------------
>  Operation            .
>  docker-name          
>```

Managing SLAAC Components: Radvd and Dibbler-Server
----------------------------------------------------

### Retrieve Radvd Configuration

**URL Path:** `/ipoe/radvd`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=config&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "config_file_name": "radvd.conf",
   "config_file_contents": [
   {
     "interface": {
       "value":"eth1",
       "AdvManagedFlag": "off",
       "AdvOtherConfigFlag": "on",
       "AdvSendAdvert": "on",
       "AdvDefaultPreference": "high",
       "MaxRtrAdvInterval": "30",
       "AdvLinkMTU": 1480,
       "prefix": {
         "value":"FD64:8D64: AF0C:2286: /64",
         "AdvOnLink": "on",
         "AdvAutonomous": "on"
       }
     }
   }]
 }
 Or
 {
   "Docker does not exist or IPv6 is not enabled"
 }
```
**Description:**

> Retrieve configuration data used by "radvd" to support SLAAC functions
> in the client PC attached to the ONU.

**Additional Notes:**

>*Parameter:*prefix

>*Description&Handling:* The prefix value is constructed based on the IPv6 prefix (FD64:8D64:AF0C::/48) received from the DHCP6 server concatenated with STAG\*256+CTAG value to get 64 bit prefix. 
The radvd will assign the IPv6 address for the LAN interface (eth1) based on this prefix value:`<EUI-64>`. 
The EUI-64 is the MAC address of the eth1 port extended to 64 bits according to EUI-64 rules.

>*Parameter:* AdvManagedFlag and AdvOtherConfigFlag

>*Description&Handling:* By setting AdvManagedFlag to off and AdvOtherConfigFlag to On allow radvd to work with dibbler-server to provide DNS-address, NTP-server-address to the client PCs attached to the ONU.

### Retrieve radvd Status

**URL Path:** `/ipoe/radvd`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=status&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "status": "Running"
 }
 Or
 {
   "status": "Stopped"
 }
 Or
 {
   "status": "Docker does not exist "
 }
```
**Description:**

> Retrieve the status of "radvd" program located inside the docker instance matching the name provided by the "docker\_name" parameter.

### Stop/Start/Restart radvd Program

**URL Path:** `/ipoe/radvd`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `POST`

**Request Data:**
```
"operation=start&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "Success"
 }
 Or
 {
   "Docker is not running or IPv6 is not enabled"
 }
```
**Description:**

> Command to start, stop or restart the radvd program.

**Additional Notes:**

>*Parameter:* operation

>*Description&Handling*: By setting the parameter operation="stop" or operation="restart", the radvd can be stopped or restarted.

### Retrieve Dibbler-ServerConfiguration

**URL Path:** `/ipoe/dibbler-server`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=config&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "config_file_name": "server.conf",
   "config_file_contents": [{
     "log-level": 7,
     "log-mode": "short",
     "stateless": true,
     "iface":{
       "value":"eth1",
       "dns-server": "2001:4860:4860::8887",
       "domain": "fj-ipoe.net",
       "ntp-server": "fd64:8d64:af0c:1::1083"
     }
   }]
 }
 Or
 {
   "Docker does not exist or IPv6 is not enabled"
 }
```
**Description:**

> Retrieve configuration data used by "dibbler-server" program to provide DNS-server address, NTP-server-address and possibly, SIP-server-address to the client PC attached to the ONU.

**Additional Notes:**

>*Parameter:* stateless

>*Description&Handling:* Dibbler-server should operate in "stateless" mode. Otherwise, it would conflict with "radvd" server.

### Retrieve dibbler-server Status

**URL Path:** `/ipoe/dibbler-server`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `GET`

**Request Data:**
```
"type=status&docker-name=vcpe-34-134"
```
**Response Data:**
```
 {
   "status": "Running"
 }
 Or
 {
   "status": "Stopped"
 }
 Or
 {
   "status": "Docker does not exist"
 }
```
**Description:**

> Retrieve the status of "dibbler-server" program located inside the docker instance matching the name provided by the "docker\_name" parameter.

### Stop/Start/Restart dibbler-server Program

**URL Path:** `/ipoe/dibbler-server`

**Target Address:** `<vsg-server-ip>:9020`

**Parameter:** `None`

**Method:** `POST`

**Request Data:**
```
"operation=start&docker-name=vcpe-34-134"
```
**Response Data:**
```
 None
```
**Description:**

> Command to start, stop or restart the dibbler-server program.

**Additional Notes:**

>*Parameter:* operation

>*Description&Handling:* To stop or restart the dibbler-server, set the operation parameter value to "stop" and "restart" respectively.
