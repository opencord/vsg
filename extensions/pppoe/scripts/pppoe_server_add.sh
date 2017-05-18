#!/bin/bash
PPPOE_SERVER_IP=$1
curl -X POST http://10.3.0.1:24000/rest:$PPPOE_SERVER_IP:3000
