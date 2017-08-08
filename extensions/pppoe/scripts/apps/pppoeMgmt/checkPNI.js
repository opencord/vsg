
/*
 * Copyright 2017-present Open Networking Foundation

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


/**
 * checkPNI - starts with the system manager input CLI command in ONOS console that enable/disable the PPPoE service.
 */
var Promise=require('bluebird');
var execAsync=Promise.promisify(require('child_process').exec);
var fs=require('fs');
var os=require('os');
var ifaces = os.networkInterfaces();
var oriGw = '10.6.1.129';
var dnsFwdr = '8.8.8.8';


//ip6tables -I FORWARD 1 -i eth1 -j DROP
function disconnDev(iface) {

    var cmd = 'ip6tables -w -I FORWARD 1 -i ' + iface + ' -j DROP';
    var checkCmd = 'ip6tables -w -v -L FORWARD 1';
    var check = 'DROP       all      ' + iface;

    console.log(checkCmd + ' to check ' + check);
    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) > 0) {
            console.log("Forward rule exists.");
        }
        else {
            execAsync(cmd);
            console.log(cmd);
        }
    }, function (err) {console.error(err);});

}

//ip6tables -D FORWARD -i eth1 -j DROP
function connDev(iface) {
    var cmd = 'ip6tables -w -D FORWARD -i ' + iface + ' -j DROP';
    var checkCmd = 'ip6tables -w -v -L FORWARD 1';
    var check = 'DROP       all      ' + iface;

    console.log(checkCmd + ' to check ' + check);
    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) > 0) {
            execAsync(cmd);
            console.log(cmd);
        }
        else {
            console.log("Forward rule not exist.");
        }
    }, function (err) {console.error(err);});

}

function natRedirectPkt(iface, ipAddr, port) {

    var cmd = 'ip6tables -w -t nat -A PREROUTING -i ' + iface +
      ' -p tcp --dport ' + port + ' -j DNAT  --to-destination ['
      + ipAddr + ']:' + port;
    var checkCmd = 'ip6tables -w -t nat -v -L PREROUTING';
    var check = 'to:[' + ipAddr + ']:' + port;

    console.log(checkCmd + ' to check ' + check);
    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) > 0) {
            console.log("nat rule exists.");
        }
        else {
            execAsync(cmd);
            console.log(cmd);
        }
    }, function (err) {console.error(err);});

}

function natRecoverPkt(iface, ipAddr, port) {

    var cmd = 'ip6tables -w -t nat -D PREROUTING -i ' + iface +
      ' -p tcp --dport ' + port + ' -j DNAT  --to-destination ['
      + ipAddr + ']:' + port;
    var checkCmd = 'ip6tables -w -t nat -v -L PREROUTING';
    var check = 'to:[' + ipAddr + ']:' + port;

    console.log(checkCmd + ' to check ' + check);
    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) > 0) {
            execAsync(cmd);
            console.log(cmd);
        }
        else {
            console.log("nat rule not exist.");
        }
    }, function (err) {console.error(err);});

}

function natMasquerade(iface) {

    var cmd = 'iptables -w -t nat -A POSTROUTING --out-interface '
      + iface + ' -j MASQUERADE';
    var checkCmd = 'iptables -w -t nat -v -L POSTROUTING';
    var check = 'MASQUERADE  all  --  any    ' + iface;

    console.log(checkCmd + ' to check ' + check);
    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) > 0) {
            console.log("nat rule exists.");
        }
        else {
            execAsync(cmd);
            console.log(cmd);
        }
    }, function (err) {console.error(err);});

}

function natRmMasquerade(iface) {

    var cmd = 'iptables -w -t nat -D POSTROUTING --out-interface '
      + iface + ' -j MASQUERADE';
    var checkCmd = 'iptables -w -t nat -v -L POSTROUTING';
    var check = 'MASQUERADE  all  --  any    ' + iface;

    console.log(checkCmd + ' to check ' + check);
    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) > 0) {
            execAsync(cmd);
            console.log(cmd);
        }
        else {
            console.log("nat rule not exist.");
        }
    }, function (err) {console.error(err);});

}

function natRmDfltGw(ipAddr) {

    var cmd = 'route del default gw ' + ipAddr;
    var checkCmd = 'ip route';
    var check = 'default via ' + ipAddr;

    console.log(checkCmd + ' to check ' + check);

    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) >= 0) {
            execAsync(cmd);
            console.log(cmd);
        }
        else {
            console.log("default gw " + ipAddr + " not exists.");
        }
    }, function (err) {console.error(err);});

}

function natAddDfltGw(ipAddr, dev) {

    var cmd = 'route add default gw ' + ipAddr + ' dev ' + dev;
    var checkCmd = 'ip route';
    var check = 'default via ' + ipAddr;

    console.log(checkCmd + ' to check ' + check);

    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) >= 0) {
            console.log("default gw " + ipAddr + " exists.");
        }
        else {
            execAsync(cmd);
            console.log(cmd);
        }
    }, function (err) {console.error(err);});

}

function setDnsRoute(ipAddr, gw, dev) {

    var cmd = 'route add ' + ipAddr + ' gw ' + gw + ' dev ' + dev;
    var checkCmd = 'ip route';
    var check = ipAddr + ' via ' + gw;

    console.log(checkCmd + ' to check ' + check);

    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) >= 0) {
            console.log("route " + ipAddr + " exists.");
        }
        else {
            execAsync(cmd);
            console.log(cmd);
        }
    }, function (err) {console.error(err);});

}

function rmDnsRoute(ipAddr) {

    var cmd = 'route del ' + ipAddr;
    var checkCmd = 'ip route';
    var check = ipAddr + ' via';

    console.log(checkCmd + ' to check ' + check);

    execAsync(checkCmd).then(function (result) {
        console.log("indexOf:" + result.indexOf(check));
        if (result.indexOf(check) >= 0) {
            execAsync(cmd);
            console.log(cmd);
        }
        else {
            console.log("route " + ipAddr + " not exists.");
        }
    }, function (err) {console.error(err);});

}

function pppoeMasquerade() {
    natMasquerade('ppp0');
}

function pppoeRmMasquerade() {
    natRmMasquerade('ppp0');
}

function pppoeRedirectPkt(ipAddr) {
    natRedirectPkt('eth1', ipAddr, '80');
    natRedirectPkt('eth1', ipAddr, '443');
    disconnDev('eth1');
}

function pppoeRmRedirectPkt(ipAddr) {
   natRecoverPkt('eth1', ipAddr, '80');
   natRecoverPkt('eth1', ipAddr, '443');
   connDev('eth1');
}

function pppoeSetRoute() {
    natRmDfltGw(oriGw);
    setDnsRoute(dnsFwdr, oriGw, 'eth0');
}

function pppoeRmRoute() {
    natAddDfltGw(oriGw, 'eth0');
    rmDnsRoute(dnsFwdr);
}

module.exports = {
    check:function(adminState,endSession){
        var adminEnable = "enable";
        var adminDisable = "disable";
        return execAsync("cat adminState.txt ").then(function (result) {
            var i = false;
            ifaces['eth1'].forEach(function(details){
                if (details.family=='IPv6' && i == false) 
                {
                    i = true;
                    eh1ip = details.address;
                    console.log('eh1ip:'+eh1ip);
                }

            });
            console.log("result:"+ result);
            if(adminState == adminEnable)
            {
                if(result.indexOf(adminDisable) > 0  && endSession == false)
                {
                    pppoeRedirectPkt(eh1ip);
                    pppoeMasquerade();
                    pppoeSetRoute();
                    var writeData = '"admin-state": "enable","end-session": "false"';
                    console.log("writeData :"+writeData);
                    fs.writeFile('adminState.txt',writeData, function(err){
                        if(err) throw err;
                        console.log("write success.");
                    });
                    return true;
                }
                else if (result.indexOf(adminEnable) > 0 && endSession == true)
                {
                    return execAsync('ps -ef|grep pppd').then(function (result) {
                        console.log("indexOf:"+result.indexOf("call provider"));
                        if (result.indexOf("call provider") > 0)
                        {
                            execAsync("poff -a");
                            pppoeRedirectPkt(eh1ip);
                            pppoeSetRoute();
                            console.log("poff ok.");
                            var writeData = '"admin-state": "enable","end-session": "true"';
                            console.log("writeData :"+writeData);
                            fs.writeFile('adminState.txt',writeData, function(err){
                                if(err) throw err;
                                console.log("write success.");
                                
                            });    
                            return true;
                        }
                    }, function (err) {
                        console.error(err);
                        return false;
                    });
                   
                }
                else
                {
                    console.log("NO enable case");
                    return false;
                }
            }
            else if(adminState == adminDisable)
            {
                if (result.indexOf(adminEnable) > 0 && endSession == false)
                {
                    return execAsync('ps -ef|grep pppd').then(function (result) {
                        console.log("indexOf:"+result.indexOf("call provider"));
                        if (result.indexOf("call provider") > 0)
                        {
                            execAsync("poff -a");
                            console.log("poff ok.");
                        }

                        pppoeRmRedirectPkt(eh1ip);
                        pppoeRmMasquerade();
                        pppoeRmRoute();

                        var writeData = '"admin-state": "disable","end-session": "false"';
                        console.log("writeData :"+writeData);
                        fs.writeFile('adminState.txt',writeData, function(err){
                            if(err) throw err;
                            console.log("write success.");
                        });
                        return true;
                    }, function (err) {
                        console.error(err);
                        return false;
                    });
                }
                else
                {
                    console.log("NO disable case");
                    return false;
                }                    
            }
        }, function (err) {
            console.log("cat adminState.txt fail");
            return false;
        });
    }
}
