#!/usr/bin/python
import os
import sys
import binascii

def main(argv):
    duid='0a0000030001'
    mac=argv[1]
    docker_name=argv[2]
    mac=mac.replace(':',"")
    duid=duid+mac
    print duid
    duid_path="/tmp/duid_" +docker_name
    duid_value_path="/tmp/duid_value_"+docker_name
    duid_bin=binascii.a2b_hex(duid)
    fname=open(duid_path,"w")
    fname.write(duid_bin)
    fname.close()
    duidv=binascii.b2a_hex(duid_bin)
    duidv=duidv.replace("0a00","");
    fduid=open(duid_value_path,"w")
    fduid.write(duidv)
    fduid.close()   

if __name__ == '__main__' :
   main(sys.argv)
