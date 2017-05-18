#!/usr/bin/env bash

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
