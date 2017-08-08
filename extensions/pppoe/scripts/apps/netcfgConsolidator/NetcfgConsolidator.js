
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
 * NetcfgConsolidator - Contains PPPoE device report functions
 */
var jsonServer = require('json-server')
var server = jsonServer.create()
var router = jsonServer.router('db.json')
var middlewares = jsonServer.defaults()
var fs=require('fs');
var __dirname = "/usr/local/lib/node_modules"
var sendOper = require(__dirname + '/addAndDeleteApList')
// Set default middlewares (logger, static, cors and no-cache)
server.use(middlewares)

server.post('/:device',function(req,res){
    console.log("device:"+req.params.device);
    var device = req.params.device;
    var str = device.split(":");
    console.log("str:"+str);
    console.log("enter post");
    console.log("port:"+str[2]);
    var netcfgDbObj = {};
    var testjson = {"ip":str[1],"port":parseInt(str[2]),"protocol": "http"};
    netcfgDbObj = JSON.parse(fs.readFileSync(__dirname + '/netconfigdb.json'));
    console.log(JSON.stringify(netcfgDbObj));
    var resProm = sendOper.addApList(netcfgDbObj,testjson,device);
    console.log(resProm);
    var data =  {"state":"Add data success."};
    res.jsonp(data)


})
server.delete('/:device',function(req,res){
    var device = req.params.device;
    console.log("device:"+device);
    var str = device.split(":");
    console.log("enter delte");
    var netcfgDbObj = {};
    var testjson = {"ip":str[1],"port":str[2],"protocol": "http"};
    console.log(testjson);
    netcfgDbObj = JSON.parse(fs.readFileSync(__dirname + '/netconfigdb.json'));
    var resProm = sendOper.deleteApList(netcfgDbObj,testjson,device);
    console.log(resProm);
    var data =  {"state":"Delete data success."}
    res.jsonp(data)
})

server.use(router)
server.listen(24000, function () {
    console.log('NETCFG-Consolidator Server is running')
})
