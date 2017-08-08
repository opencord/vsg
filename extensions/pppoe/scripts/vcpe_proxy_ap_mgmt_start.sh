
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

