
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
 * httpServer_ipv4 - HTTP server for user's credential
 */
var express = require('express');
var path = require('path');
var http  = require('http');
var https = require('https');
var radiusOper = require('./startClient');
var body_parser = require('body-parser');
var os=require('os');
var ifaces = os.networkInterfaces();
var app = express();
var fs = require("fs");
var Promise=require('bluebird');
var execAsync=Promise.promisify(require('child_process').exec);
app.use(express.static(path.join(__dirname,'authwebapp')));

var config = {
    key: fs.readFileSync('./certs/server.key'),
    cert: fs.readFileSync('./certs/server.crt'),
    ca: fs.readFileSync('./certs/ca.crt'),
    requestCert: true,
    rejectUnauthorized: false
};

function natRecoverPkt(iface, ipAddr, port) {

    var cmd = 'iptables -w -t nat -D PREROUTING -i ' + iface +
      ' -p tcp --dport ' + port + ' -j DNAT  --to-destination '
      + ipAddr + ':' + port;
    var checkCmd = 'iptables -w -t nat -v -L PREROUTING';
    var check = 'to:' + ipAddr + ':' + port;

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

function connDev(iface) {
    var cmd = 'iptables -w -D FORWARD -i ' + iface + ' -j DROP';
    var checkCmd = 'iptables -w -v -L FORWARD 1';
    var check = 'DROP       all  --  ' + iface;

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

function rmDnsRoute(ipAddr) {
    //delete blindly, minor side effect
    var cmd = 'route del ' + ipAddr;
    execAsync(cmd);
    console.log(cmd);
}

function pppoeRmRedirectPkt(ipAddr) {
    natRecoverPkt('eth1', ipAddr, '80');
    natRecoverPkt('eth1', ipAddr, '443');
    connDev('eth1');
    rmDnsRoute('8.8.8.8');
}

app.use(body_parser.json());
app.use(body_parser.urlencoded({ extended: true })); 

app.get('/', function (req, res) {
	
    console.log("===Please login.===" );
    execAsync('cat adminState.txt').then(function (result) {
        if (result.indexOf("enable") > 0)
        {
            res.sendFile(__dirname+'/authwebapp/login.html');
        }
        else
        {
            console.log("PPPoE disabled.");
            res.send('PPPoE disabled.');
        }
    }, function (err) {
        console.error(err);
    });
})

app.post('/',function(req,res){
    console.log("===post request===");
    var username = req.body.username;
    var password = req.body.password;
    console.log("===user:"+username+",pwd:"+password+"===");
	
    var data = radiusOper.verifyFun(username,password);
    data.then(function(result){        
        console.log("===verifyFun result:"+result+"===");
        if(result)
        {
            setTimeout(function(){
                console.log("enter timeout");     
                execAsync("ifconfig").then(function (result) {
                    console.log("result.indexOf :"+result.indexOf("ppp0"));
                    if(result.indexOf("ppp0") >= 0)
                    {
                        console.log("===PPPoE session has set up.===");
                        pppoeRmRedirectPkt(eh1ip);
                        res.setHeader("Access-Control-Allow-Origin", "*");
                        res.jsonp({'result':'Auth successfully!!'});
                    }
                    else
                    {
                        execAsync("poff -a");
                        console.log("===PPPoE session failed.===");
                        res.setHeader("Access-Control-Allow-Origin", "*");
                        res.jsonp({'result':'error!'});
                    }
                });
            },5000);    
        }
        else
        {
            execAsync("poff -a");
            console.log("===PPPoE session failed.===");
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.jsonp({'result':'error!'});
        }
    });
});
 
var eh1ip='a';
var i = false;
ifaces['eth1'].forEach(function(details){
    if (details.family=='IPv4' && i == false) 
    {
        i = true;
        eh1ip = details.address;
        console.log('eh1ip:'+eh1ip);
    }
});

var httpPort = "80";
var httpsPort = "443";

http.createServer(app).listen(httpPort, eh1ip);
https.createServer(config, app).listen(httpsPort, eh1ip);

console.log("PPPoE Web Server listens on ports " + httpPort + " and " + httpsPort);

