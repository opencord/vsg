# PPPoE Client Feature

This configuration can be used to deploy PPPoE client feature to vCPE.  
And PPPoE client that deployed to vCPE is connected to external PPPoE server via VXLAN.

## Getting Started

- Navigate to `xos_services/vsg/extensions/pppoe` folder
- Copy `scripts` folder to nova-compute
- Run `bash scripts/nova_pppoe_setup.sh` on nova-compute
> _NOTE:_  
> _The default IP version to support on user devices is IPv6 only._
> _If IPv4 only user device is to be supported, the above command should have argument as below._  
> `bash nova_pppoe_setup.sh ipv4`

When vCPE is generated, the PPPoE client feature is deployed to vCPE. This process will take a few minutes.  
The user can monitor the process by checking on the log file, or on ONOS CLI to see if the REST device for the vCPE appears.

### VXLAN Configuration

If you want to change VXLAN configuration:  

- change lines 95-101 of nova_pppoe_setup.sh (`NOVA PPPoE Params`)  
  The default values is bellow:
```
PPPoE server: "10.200.200.100"
Eth3 of Nova Compute: "10.200.200.200"
VXLAN id: "42"
```

## How To Create PPPoE Session

Connect a PC to the ONU. The PC should obtain an IP address from the vCPE.   
If PPPoE is enabled, the PC would not have internet access.  
Open a Google Chrome web browser, type in one of the following URLs to access the PPPoE client web page.

- Use the IP address of the vCPE IP address of eth1.  
   - For IPv6 support:  
     `http://[2001:468:181:f100::1]`  
   - For IPv4 support:  
     `http://192.168.0.1`  


- Use a valid domain-named URL, such as the following.  
  `https://www.google.com`  
  > _NOTE:  
  > Because of the browsers cache the site info, accessing the used web page may meet some problem. Or the browser's cache needs to be cleared._  

The login page will be displayed on the browser. Input the authenticatable username and password, and click on button Connect.  
The PPPoE client in the vCPE will initiate a PPPoE session with the username and password.  

After a while, the popup window will display the result.

Click on the OK, the page will be redirected to google.com.  
After that the user can browser to other web pages.


---

## How To Setup External PPPoE Server

### PPPoE Server Installation

PPPoE server runs on an Ubuntu 14.04 VM. The latest Roaring Penguin release  rp-pppoe-3.12.tar.gz is used.  
It can be downloaded at the following site.  
[https://www.roaringpenguin.com/products/pppoe](https://www.roaringpenguin.com/products/pppoe)  

It is installed by the following steps.  

- `tar xvf rp-pppoe-3.12.tar.gz`
- `vi rp-pppoe-3.12/src/pppoe-server.c`
- Change line 1956-1959 as following.
```
argv[c++] = "mru";
argv[c++] = "1442";
argv[c++] = "mtu";
argv[c++] = "1442";
```
  > _NOTE:_  
  > _The reason is that we use VXLAN that takes 50 bytes and PPPoE takes another 8 bytes._  
  > _We must modify the above code because this bug since version 3.11 makes "mtu" in configuration file not work._

- `cd ~/rp-pppoe-3.12/src/`
- `./configure`
- `sudo make install`

### PPPoE Server Configuration

Edit and get the following config file.

- Edit `/etc/ppp/pppoe-server-options`.
```
# PPP options for the PPPoE server
# LIC: GPL
#require-pap
require-chap
mtu 1442
#login
lcp-echo-interval 10
lcp-echo-failure 2
plugin        /usr/lib/pppd/2.4.5/radius.so
radius-config-file  /etc/radiusclient/radiusclient.conf
logfile  /var/log/pppd.log
```

### Radius Client Installation

FreeRadius client is used in this example. It is installed by the following
commands.  

- `sudo apt-get install libfreeradius-client2`
- `touch /etc/radiusclient/port-id-map`

### Radius Client Configuration

- Edit `/etc/radiusclient/radiusclient.conf`.
   - Change auth_order to radius only.  
     `auth_order      radius`  
   - Be noted that the authserver and acctserver, only the IP part, are to be configured through ONOS. For others fixed values are used.  
     `authserver      X.X.X.X:1812`  
     `acctserver      X.X.X.X:1813`  
     \* X.X.X.X : Radius Server's IP address
- Edit the communication key between the RADIUS client and the RADIUS server
  defined in `/etc/radiusclient/servers`.
```
## Server Name or Client/Server pair            Key
## ----------------                             ---------------
#
#portmaster.elemental.net                       hardlyasecret
#portmaster2.elemental.net                      donttellanyone
#
## uncomment the following line for simple testing of radlogin
## with freeradius-server
#
#localhost/localhost                            testing123
X.X.X.X                xpass1
```

## VXLAN Creation

VXLAN is provisioned to bypass possible router between PPPoE client and server.  
Suppose the eth1 of the PPPoE server VM is connected to eth2 of the head node host.  
Configure the IP address of eth1 as 10.200.200.100.  
Do not change the IP that is paired in the pppoe package script.  
`ip link add vxlanp type vxlan id 42 remote 10.200.200.200 local 10.200.200.100 dev eth1`

The VXLAN is between the PPPoE server VM eth1 and the Nova-Compute eth3.

## Start PPPoE Server

The PPPoE Server runs on the VXLAN by command like the following one.

`sudo pppoe-server -L 10.10.10.10 -I vxlanp -R 10.10.10.20 -N 50`

---

## How To Setup Radius Server

FreeRadius RADIUS server is used in this project to verify the authentication path.

### Radius Server Installation

FreeRadius and FreeRadius-MySql is used in this example. It is installed by the following commands.

- `sudo apt-get install freeradius freeradius-mysql`

### Radius Server Configuration

- Edit  `/etc/freeradius/radiusd.conf`.
  - Change auth parameter to `yes` from `no`.  
```
  #  Log authentication requests to the log file.
  #
  #  allowed values: {no, yes}
  #
  auth = yes
```

- File `/etc/freeradius/clients.conf` defines the RADIUS client with a key as the following.
```
client xuser1 {
         ipaddr = Y.Y.Y.Y
         netmask = 16
         secret = xpass1
         shortname = xuser1
         nastype     = other
      }
```

  The ipaddr (Y.Y.Y.Y) is that of the PPPoE server machine, secret must match the Key in `/etc/radiusclient/servers` of PPPoE server VM.

- The users are defined in file `/etc/freeradius/users` as like the following.
```
"user1" Cleartext-Password := "pass1"
        Service-Type = Framed-User,
        Framed-Compression = Van-Jacobsen-TCP-IP
```
For example:
```
test@isp.com  Cleartext-Password := "test"
        Service-Type = Framed-User,
        Framed-Compression = Van-Jacobsen-TCP-IP
```

  Here the user1/pass1 is the user ID and password the PPPoE client used to ask for PPPoE service.
