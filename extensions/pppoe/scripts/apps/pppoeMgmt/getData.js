/**
 * gatData - Gat pppoe client ppp0 info
 */
module.exports.get=function(result){
    var ipA; var rxP; var rxB; var txP; var txB; var temp;
    if(result.indexOf("inet addr") > 0 )
    {
        ipA = result.slice(result.indexOf("inet addr:")+10,result.indexOf("P-t-P:")-1);
    }
    else
    {
        console.log("Have not been established ppp0 network interface!");
    }

    if(result.indexOf("RX packets") > 0 )
    {
        rxP = result.slice(result.indexOf("RX packets:")+11,result.indexOf("errors:")-1);
    }
    if(result.indexOf("TX packets") > 0 )
    { 
        temp = result.slice(result.indexOf("errors:") + 1,result.indexOf("MB"));
        txP = temp.slice(temp.indexOf("TX packets:")+11,temp.indexOf("errors:")-1);
    }
    if(result.indexOf("RX bytes") > 0 )
    {
        rxB = result.slice(result.indexOf("RX bytes:")+9,result.indexOf(" ("));
    }
    if(result.indexOf("TX bytes:") > 0 )
    {
        temp = result.slice(result.indexOf(")")+1,result.indexOf("\n\n"));
		console.log("temp:"+temp);
        txB = temp.slice(temp.indexOf("TX bytes:")+9,temp.indexOf(" ("));
        console.log(txB);
    }
    
    
    var data = {
            "ip": ipA,
            "rx-packets": rxP,
            "tx-packets": txP,
            "rx-bytes": rxB,
            "tx-bytes": txB
            };
    return data;
}
