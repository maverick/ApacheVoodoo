// $Id$
//
// Ajax handler based on Sean Kane's Feather Ajax.  It has been modified to parse JSON responses using the reference implementation
// found at JSON.org.  Original copy right notices appear below.
//

//Created by Sean Kane (http://celtickane.com/programming/code/ajax.php)
//Feather Ajax v1.0.1

/*
    http://www.JSON.org/json2.js
    2008-09-01

    Public Domain.

    NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

    See http://www.JSON.org/js.html
*/

function voodooDebug(opts){
	this.debug_root = opts.debug_root;
	this.app_id     = opts.app_id;
	this.session_id = opts.session_id;
	this.request_id = opts.request_id;

	this.imgSpinner = new Image(16,16);
	this.imgMinus   = new Image(9,9);
	this.imgPlus    = new Image(9,9);

	this.imgSpinner.src = this.debug_root+"/i/spinner.gif";
	this.imgMinus.src   = this.debug_root+"/i/minus.png";
	this.imgPlus.src    = this.debug_root+"/i/plus.png";

	var levels = ["debug","info","warn","error","exception","table","trace"];
	this.imgLevels = new Object();
	for (var i in levels) {
		this.imgLevels[levels[i]] = new Image(14,14);
		this.imgLevels[levels[i]].src = this.debug_root+"/i/"+levels[i]+".png";
	}

	this.yourBrowserIsBroken=(navigator.userAgent.toLowerCase().indexOf("msie")!=-1);

	this.createRequestObject=function(){try {var ro=new XMLHttpRequest();}catch(e){var ro=new ActiveXObject("Microsoft.XMLHTTP");}return ro;};this.sndReq=function(action,url,data){if(action.toUpperCase()=="POST"){this.http.open(action,url,true);this.http.setRequestHeader('Content-Type','application/x-www-form-urlencoded');this.http.onreadystatechange=this.handleResponse;this.http.send(data);}else{this.http.open(action,url+'?'+data,true);this.http.onreadystatechange=this.handleResponse;this.http.send(null);}};this.handleResponse=function(){if(me.http.readyState==4){if(typeof me.funcDone=='function'){me.funcDone();}var rawdata=me.http.responseText;

	console.log(eval('('+rawdata+')'));
	var data = me.parse(rawdata);
	if (data.value != null && data.value.length) {
		document.getElementById(data.key).innerHTML = me.loadDisplay(data.value);
	}
	else {
		document.getElementById(data.key).innerHTML = "<i>(empty)</i>";
	}

}if ((me.http.readyState==1)&&(typeof me.funcWait=='function')){me.funcWait();}};var me=this;this.http=this.createRequestObject();var funcWait=null;var funcDone=null;this.f=function(n){return n<10?'0'+n:n;};if(typeof Date.prototype.toJSON!=='function'){Date.prototype.toJSON=function(key){return this.getUTCFullYear()+'-'+f(this.getUTCMonth()+1)+'-'+f(this.getUTCDate())+'T'+f(this.getUTCHours())+':'+f(this.getUTCMinutes())+':'+f(this.getUTCSeconds())+'Z';};String.prototype.toJSON=Number.prototype.toJSON=Boolean.prototype.toJSON=function(key){return this.valueOf();};}var cx=/[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,escapeable=/[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,gap,indent,meta={'\b':'\\b','\t':'\\t','\n':'\\n','\f':'\\f','\r':'\\r','"':'\\"','\\':'\\\\'},rep;
	this.parse=function(text,reviver){var j;function walk(holder,key){var k,v,value=holder[key];if(value&&typeof value==='object'){for(k in value){if(Object.hasOwnProperty.call(value,k)){v=walk(value,k);if(v!==undefined){value[k]=v;}else{delete value[k];}}}}return reviver.call(holder,key,value);}cx.lastIndex=0;if(cx.test(text)){text=text.replace(cx,function(a){return '\\u'+('0000'+a.charCodeAt(0).toString(16)).slice(-4);});}if(/^[\],:{}\s]*$/.test(text.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,'@').replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,']').replace(/(?:^|:|,)(?:\s*\[)+/g,''))){j=eval('('+text+')');return typeof reviver==='function'?walk({'':j},''):j;}throw new SyntaxError('JSON.parse');}
	this.loadDisplay = function(data) {
		var h;
		if (data.constructor == Array) {
			if (data[0][1].constructor == Array) {
				h = '<ul>';
				for (j=0; j < data.length; j++) {
					h += '<li class="vdOpen"><span onClick="vdDebug.toggleUL(this);">'+
						 '<img src="'+this.imgMinus.src+'" />'+
					     data[j][0]+'</span>'+
					     this.loadDisplay(data[j][1])+
						 '</li>';
				}
				h += '</ul>';
			}
			else if (data[0].length == 2) {
				h = '<dl>';
				for (j=0; j < data.length; j++) {
					console.log(j);
					h += '<dt class="vdClosed" onClick="vdDebug.toggleDL(this);">'+
						 '<img src="'+this.imgPlus.src+'" />'+
						 data[j][0].replace(/>/g,'&gt;')
						 +'</dt><dd class="vdClosed">'+
						 data[j][1].replace(/</g,'&lt;')+
						 '</dd>';
				}
				h += '</dl>';
			}
			else if (data[0].constructor == Array) {
				h = '<table><tr><th>';
				h += data[0].join('</th><th>');
				h += '</th></tr>';

				for (j=1; j < data.length; j++) {
					h += '<tr><td><pre>';
					h += data[j].join('</pre></td><td><pre>');
					h += '</td></tr>';
				}
				h += "</table>";
			}
			else {
				h = "<pre>"+data+"</pre>";
			}
		}
		else {
			h = "<span>"+data+"</span>";
		}
		return h;
	}

	this.toggleDL = function(obj) {
		if (obj.className == "vdOpen") {
			obj.className = "vdClosed";
			obj.firstChild.src=this.imgPlus.src;
			obj.nextSibling.className = "vdClosed";
		}
		else {
			obj.className = "vdOpen";
			obj.firstChild.src=this.imgMinus.src;
			obj.nextSibling.className = "vdOpen";
		}
	}

	this.toggleUL = function(obj) {
		if (obj.parentNode.className == "vdOpen") {
			obj.parentNode.className = "vdClosed";
			obj.firstChild.src=this.imgPlus.src;
			//obj.nextSibling.className = "vdClosed";
		}
		else {
			obj.parentNode.className = "vdOpen";
			obj.firstChild.src=this.imgMinus.src;
			//obj.nextSibling.className = "vdOpen";
		}
	}

	this.handleSection = function(obj, section) {
		if (obj.parentNode.className == "vdOpen") {
			obj.parentNode.className = 'vdClosed';
			obj.firstChild.src=this.imgPlus.src;
		}
		else {
			obj.parentNode.className = 'vdOpen';
			obj.firstChild.src=this.imgMinus.src;

			if (section != "top") {
				document.getElementById("vd_"+section).innerHTML = '<img src="'+this.imgSpinner.src+'">';	
				this.sndReq('get',this.debug_root+"/"+section,
					'app_id='+this.app_id+
					'&session_id='+this.session_id+
					'&request_id='+this.request_id
				);
			}
		}

		if (this.yourBrowserIsBroken) {
			var selectState;
			if (section == "top") {
				selectState = (obj.parentNode.className == "vdOpen") ? 'hidden': 'visible';
			}
			else {
				selectState = 'hidden';
			}
			var selects = document.getElementsByTagName("SELECT");
			for (var i = 0; i < selects.length; i++) {
				selects[i].style.visibility = selectState;
			}
		}
		return false;
	}

	this.toggleFilter = function(obj,section) {
	}
}
