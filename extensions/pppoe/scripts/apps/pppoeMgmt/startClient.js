
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
 * startClient - start pppoe client
 */
var fs=require("fs");
var Promise=require('bluebird');
var execAsync=Promise.promisify(require('child_process').exec);

String.prototype.trim = function() {
    return this.replace(/^\s\s*/, '').replace(/\s\s*$/, '');
}

module.exports={
    verifyFun:function(userName,passWord){
        return execAsync("ifconfig").then(function (result) {
            if(result.indexOf("ppp0") > 0)
            {
                console.log("PPPoE session up.");
                return true;
            }
            else
            {
                var data =
                  "noipdefault\n" +
                  "usepeerdns\n" +
                  "defaultroute\n" +
                  "replacedefaultroute\n" +
                  "hide-password\n" +
                  "lcp-echo-interval 20\n" +
                  "lcp-echo-failure 3\n" +
                  "noauth\n" +
                  "persist\n" +
                  "mtu 1442\n" +
                  "noaccomp\n" +
                  "default-asyncmap\n" +
                  "pty \"pppoe -I eth2 -T 80\"\n" +
                  "user \"" + userName + "\"\n";

                var secretData = "\"" + userName + "\"" + " * " + "\"" + passWord + "\"";
                console.log("data:"+data+",secretData:"+secretData);
          
                fs.writeFile('/etc/ppp/peers/provider',data, function(err){
                    if(err) throw err;
                    console.log("write provider.");
                });

                fs.writeFile('/etc/ppp/chap-secrets',secretData,function(err){
                    if(err) throw err;
                    console.log("write chap-secrets.");
                });

                return execAsync('ps -ef|grep pppd').then(function (result) {
                    if (result.indexOf("call provider") > 0)
                    {
                        execAsync("poff -a").then(function (result) {
                        execAsync('pon');
                        console.log("restart");
                        }, function (err) {
                            console.log(err);
                        });
                    }
                    else
                    {
                        execAsync('pon');
                        console.log("start");
                    }
                    return true;
                }, function (err) {
                    console.log(err);
                    return false;
                });
            }
        });    
    }
}
