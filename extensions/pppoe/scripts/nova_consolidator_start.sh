#!/bin/bash
#************************************************************/
#** File:         nova_consolidator_start.sh                */
#** Contents:     Contains shell script to start Nova       */
#**               Consolidator application                  */
#************************************************************/

cd /usr/local/lib/node_modules/
sudo nodejs NetcfgConsolidator.js > /home/ubuntu/NetcfgConsolidator.log 2>&1 &

