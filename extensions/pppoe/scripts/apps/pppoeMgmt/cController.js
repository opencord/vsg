
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
 * cController - PPPoE C_Controller
 */
var jsonServer = require('json-server');
var Promise=require('bluebird');
var fs=require('fs');
var client = jsonServer.create();
var middlewares = jsonServer.defaults();
var execAsync=Promise.promisify(require('child_process').exec);
var checkPNI=require('./checkPNI');
var getData=require('./getData');
var os=require('os');
var ifaces = os.networkInterfaces();
client.use(middlewares)

/*keep alive with onos */
client.get('/',function(req,res){
    //no data back.
    res.jsonp();
})

client.get('/pppoe/device',function(req,res){
    var data={"type": "client"};
    console.log("data:"+data);
    res.jsonp(data)
})

client.get('/pppoe/session',function(req,res){
    var data = "";
    var cat = "ifconfig ppp0 ";
    execAsync(cat).then(function (result) {
        console.log(cat + " done");    
        var data = getData.get(result);
        res.jsonp(data)
    }, function (err) {
        var data = {
          "ip": "0.0.0.0",
          "rx-packets": 0,
          "tx-packets": 0,
          "rx-bytes": 0,
          "tx-bytes": 0
        };
        res.jsonp(data)
    });
})

client.put('/pppoe/config',function(req,res){
    var adminState;  
    var endSession = false;
    req.on('data', function (data) {
        try{
            var dataJson = JSON.parse(data.toString());
            adminState = dataJson['admin-state'];
            endSession = dataJson['end-session'];
        }
        catch(e){
            console.log('error.');
            res.jsonp(false)
        }
        console.log("adminState:"+adminState);
        console.log("endSession:"+endSession);
        var data = checkPNI.check(adminState, endSession);
        data.then(function (result){
            
                console.log("result:"+result);
                res.jsonp(result)
            
        });    
    })
})

client.get('/pppoe/info',function(req,res){ 
    execAsync("cat adminState.txt ").then(function (result) {
        var state = result.slice(result.indexOf("admin-state")+13,result.indexOf(","));
        var infoStr = fs.readFileSync('info.txt').toString();
        var strarray = infoStr.match(/\d{1,4}/g); 
        var svlan = strarray[0];        
        var cvlan = strarray[1];
        console.log(infoStr);
        var data = {
            "admin-state" : JSON.parse(state),
            "s-vlan" : JSON.parse(svlan),
            "c-vlan" : JSON.parse(cvlan)
            };
        res.jsonp(data);
    }, function (err) {
            var data = {
            "admin-state" : "0",
            "s-vlan": 0,
            "c-vlan": 0
            }
            res.jsonp(data);
    });
})

ifaces['eth0'].forEach(function(details){
    if (details.family=='IPv4') {
        eh0ip = details.address;
        console.log('eh0ip:'+ eh0ip);
    }
});
  
client.listen(3000, eh0ip, function (req,res) {
    console.log('PPPoE c-Controller ' + eh0ip + ':3000 is running.');
});
