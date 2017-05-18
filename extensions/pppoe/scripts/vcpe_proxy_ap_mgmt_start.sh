#!/bin/bash
#************************************************************/
#** File:         vcpe_proxy_ap_mgmt_start.sh               */
#** Contents:     Contains shell script to start VCPE       */
#**               PPPoE Management                          */
#************************************************************/
echo "vcpe_proxy_ap_mgmt_start.sh: BEGIN" >/tmp/pppoeMgmt.log
date >>/tmp/pppoeMgmt.log

cd /usr/local/lib/node_modules/
# TODO:
# Need to fix this hardcoded filename
### Replace apmgmt_js.tar by the variable $APMGMT_TAR_FILE
tar -xvf apmgmt_js.tar

if [[ "$1" == "ipv4" ]]; then
    cp checkPNI_ipv4.js checkPNI.js
    cp httpServer_ipv4.js httpServer.js
fi

nodejs httpServer.js >> /tmp/httpServer.log 2>&1 &
nodejs cController.js >> /tmp/cController.log 2>&1 &

