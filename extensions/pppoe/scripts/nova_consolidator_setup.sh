
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


#!/usr/bin/env bash
#************************************************************/
#** File:         nova_consolidator_setup.sh                */
#** Contents:     Contains shell script to setup required   */
#**               software for Nova Consolidator application*/
#************************************************************/

sudo apt-get update -y
sudo apt-get install npm -y
echo "#### Install Json-Server ####"
sudo npm install -g json-server@0.9.6
cd /usr/local/lib/node_modules
echo "#### Install Line-Reader ####"
sudo npm install -g line-reader
echo "#### Install Blue-Bird ####"
sudo npm install -g bluebird
echo "#### Install JS files ####"
sudo cp /usr/local/pppoe/utils/netcfgConsolidator/* /usr/local/lib/node_modules/.
