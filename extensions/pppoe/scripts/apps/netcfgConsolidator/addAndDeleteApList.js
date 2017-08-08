
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
 * addAndDeleteApList - Contains PPPoE device report functions
 */
var fs=require('fs');
var Promise = require('bluebird');
var request = Promise.promisifyAll(require('request'));
var __dirname = "/usr/local/lib/node_modules";
module.exports={
    addApList:function(netcfgDbObj,testjson,device){
        console.log("add ap list!");
        var APList = netcfgDbObj.apps['org.onosproject.restsb'].devices;
        var DeviceList = netcfgDbObj.devices;
        DeviceList[device] = { "basic": { "driver": "rest-pppoe" } };
        var flag = true;
        for(var i = 0;i< APList.length;i++) {
            if((testjson.ip == APList[i].ip) && (testjson.port == APList[i].port)) {
                flag = false;
            }
        }
        if(flag) {
            APList.push(testjson);
        }
        var APListObj = {"devices": DeviceList,"apps":{"org.onosproject.restsb":{"devices":APList}}};
        console.log("add test!!!!")
        console.log(JSON.stringify(APListObj));
        console.log("add test!!!!");
        fs.writeFile(__dirname + '/netconfigdb.json', JSON.stringify(APListObj), function(err) {
            if (err) {
                throw err;
            }
            console.log('Saved.');
        });
        console.log("Add one data,and report to ONOS!");
        var config = JSON.parse(fs.readFileSync(__dirname + '/NetcfgConfig.json'));
        console.log(config);
        var waitTimeout = 10000;
        setTimeout(function() {
            console.log("Delayed POST reqeust: Add AP List!");
            request({
                url: "http://"+config.OnosIP+":8182/onos/v1/network/configuration/",
                method: "POST",
                json: true,   // <--Very important!!!
                body: APListObj,
                auth: {
                    username: 'onos',
                    password: 'rocks'
                }
            }, function (error, response, body){
                console.log(error);
                //console.log(response);
            });
        }, waitTimeout);
        var rep =  {"status":true};
        return rep;
    },
    deleteApList:function(netcfgDbObj,testjson,device){
        console.log("delete ap list!");
        var APList =  netcfgDbObj.apps['org.onosproject.restsb'].devices;
        var DeviceList = netcfgDbObj.devices;
        delete DeviceList[device];
        var tempList = new Array();
        for (var i = 0;i< APList.length;i++) {
            if((testjson.ip == APList[i].ip) && (testjson.port == APList[i].port)) {

            } else {
                tempList.push(APList[i]);
            }
        }
        var APListObj = {"devices": DeviceList,"apps":{"org.onosproject.restsb":{"devices":tempList}}};
        console.log("delete test!!!!")
        console.log(JSON.stringify(APListObj));
        console.log("delete test!!!!");
        fs.writeFile(__dirname + '/netconfigdb.json', JSON.stringify(APListObj), function(err) {
            if (err) {
                throw err;
            }
            console.log('Saved.');
        });
        console.log("Delete one data,and report to ONOS!");
        var config = JSON.parse(fs.readFileSync(__dirname + '/NetcfgConfig.json'));
        console.log(config);
        request({
            url: "http://"+config.OnosIP+":8182/onos/v1/network/configuration/devices/"+device,
            method: "DELETE",
            json: true,   // <--Very important!!!
            auth: {
                username: 'onos',
                password: 'rocks'
            }
        }, function (error, response, body){
            console.log(error);
            // console.log(response);
        });
        request({
            url: "http://"+config.OnosIP+":8182/onos/v1/network/configuration/",
            method: "POST",
            json: true,   // <--Very important!!!
            body: APListObj,
            auth: {
                username: 'onos',
                password: 'rocks'
            }
        }, function (error, response, body){
            console.log(error);
        });
        var rep =  {"status":true};
        return rep;
    },
    deleteReportOnos:function(){
        var netcfgDbObj = {};
        var APList = new Array();
        var tempList = new Array();
        netcfgDbObj = JSON.parse(fs.readFileSync(__dirname + '/netconfigdb.json'));
        APList = netcfgDbObj.AP;
        for(var i = 0;i < APList.length; i++) {
            if(APList[i].status === "Available") {
                tempList.push(APList[i]);
            }
        }
        var data = {"AP":tempList};
        //report onos
    }
}
