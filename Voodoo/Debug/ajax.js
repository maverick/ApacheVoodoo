// $Id$
//
// Combined and compressed version of the reference JSON parser found on json.org and Sean Kane's Feather Ajax.  The later
// of which has been modified to parse JSON responses.
//

/*
    http://www.JSON.org/json2.js
    2008-09-01

    Public Domain.

    NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

    See http://www.JSON.org/js.html
*/
if(!this.JSON){JSON={};}(function(){function f(n){return n<10?'0'+n:n;}if(typeof Date.prototype.toJSON!=='function'){Date.prototype.toJSON=function(key){return this.getUTCFullYear()+'-'+f(this.getUTCMonth()+1)+'-'+f(this.getUTCDate())+'T'+f(this.getUTCHours())+':'+f(this.getUTCMinutes())+':'+f(this.getUTCSeconds())+'Z';};String.prototype.toJSON=Number.prototype.toJSON=Boolean.prototype.toJSON=function(key){return this.valueOf();};}var cx=/[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,escapeable=/[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,gap,indent,meta={'\b':'\\b','\t':'\\t','\n':'\\n','\f':'\\f','\r':'\\r','"':'\\"','\\':'\\\\'},rep;if(typeof JSON.parse!=='function'){JSON.parse=function(text,reviver){var j;function walk(holder,key){var k,v,value=holder[key];if(value&&typeof value==='object'){for(k in value){if(Object.hasOwnProperty.call(value,k)){v=walk(value,k);if(v!==undefined){value[k]=v;}else{delete value[k];}}}}return reviver.call(holder,key,value);}cx.lastIndex=0;if(cx.test(text)){text=text.replace(cx,function(a){return '\\u'+('0000'+a.charCodeAt(0).toString(16)).slice(-4);});}if(/^[\],:{}\s]*$/.test(text.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g, '@').replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,']').replace(/(?:^|:|,)(?:\s*\[)+/g,''))){j=eval('('+text+')');return typeof reviver==='function'?walk({'': j},''):j;}throw new SyntaxError('JSON.parse');};}})();

//Created by Sean Kane (http://celtickane.com/programming/code/ajax.php)
//Feather Ajax v1.0.1
function AjaxObject101(){this.createRequestObject=function(){try{var ro=new XMLHttpRequest();}catch(e){var ro=new ActiveXObject("Microsoft.XMLHTTP");}return ro;};this.sndReq=function(action,url,data){if(action.toUpperCase()=="POST"){this.http.open(action,url,true);this.http.setRequestHeader('Content-Type','application/x-www-form-urlencoded');this.http.onreadystatechange=this.handleResponse;this.http.send(data);}else{this.http.open(action,url+'?'+data,true);this.http.onreadystatechange=this.handleResponse;this.http.send(null);}};this.handleResponse=function(){if(me.http.readyState==4){if(typeof me.funcDone=='function'){me.funcDone();}

console.log(JSON.parase(me.http.responseText));

}if((me.http.readyState==1)&&(typeof me.funcWait=='function')){me.funcWait();}};var me=this;this.http=this.createRequestObject();var funcWait=null;var funcDone=null;}

