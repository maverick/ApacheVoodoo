// $Id$
//
// Ajax handler for Voodoo's native debugging functions.  This object contains  
// both Sean Kane's Feather Ajax and the reference JSON parser found at JSON.org.
// The original copyright notices for those components appear below, along with
// comments in the code noting where they begin, end and how they were modified.

//Created by Sean Kane (http://celtickane.com/programming/code/ajax.php)
//Feather Ajax v1.0.1

/*
    http://www.JSON.org/json2.js
    2008-11-19

    Public Domain.

    NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

    See http://www.JSON.org/js.html

	This is a reference implementation. You are free to copy, modify, or
    redistribute.

    This code should be minified before deployment.
    See http://javascript.crockford.com/jsmin.html

    USE YOUR OWN COPY. IT IS EXTREMELY UNWISE TO LOAD CODE FROM SERVERS YOU DO
    NOT CONTROL.

*/

function voodooDebug(opts) {
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

	var levels = new Array("debug","info","warn","error","exception","table","trace");
	this.imgLevels = new Object();
	for (var i=0; i < levels.length; i++) {
		this.imgLevels[levels[i]] = new Image(12,12);
		this.imgLevels[levels[i]].src = this.debug_root+"/i/"+levels[i]+".png";
	}

	this.yourBrowserIsBroken = (navigator.userAgent.toLowerCase().indexOf("msie")!=-1);

	//////////////////////////////////////////////////////////////////////////////////
	// Beginning of Feather Ajax
	//////////////////////////////////////////////////////////////////////////////////

	this.createRequestObject = function() {
		try {
			var ro=new XMLHttpRequest();
		}
		catch(e) {
			var ro=new ActiveXObject("Microsoft.XMLHTTP");
		}
		return ro;
	}

	this.http = this.createRequestObject();
	var me = this;
	this.sndReq = function(action,url,data) {
		if (action.toUpperCase()=="POST") {
			this.http.open(action,url,true);
			this.http.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
			this.http.onreadystatechange=this.handleResponse;
			this.http.send(data);
		}
		else {
			this.http.open(action,url+'?'+data,true);
			this.http.onreadystatechange=this.handleResponse;
			this.http.send(null);
		}
	}

	this.handleResponse = function() {
		// Callbacks stripped;
		if (me.http.readyState==4) {
			me.handleDisplay(me.http.responseText);
		}
	}

	//////////////////////////////////////////////////////////////////////////////////
	// End of Feather Ajax
	//////////////////////////////////////////////////////////////////////////////////

	this.handleTable = function(data,title) {
		var h = '<table>';
		if (typeof (title) != "undefined") {
			h += '<caption><img src="'+this.imgLevels['table'].src+'"/>'+title+'</caption>';
		}
		h += '<tr><th>'+data[0].join('</th><th>')+'</th></tr>';

		for (j=1; j < data.length; j++) {
			h += '<tr><td><pre>';
			h += data[j].join('</pre></td><td><pre>');
			h += '</td></tr>';
		}
		h += "</table>";
		return h;
	}

	this.handleDebug = function(data) {
		var h = '<dl>';
		for (var i=0; i < data.length; i++) {
			h += '<dt class="vdClosed" onClick="vdDebug.toggleDL(this);">'+
				'<img src="'+this.imgPlus.src+'" />'+


				'</dt><dd class="vdClosed">'+
				'<img src="'+this.imgLevels[data[i].level].src+'"/>'+
				// data[j][1].replace(/</g,'&lt;')+
				'</dd>';
		}
		h += '</dl>';
		return h;
	}

	this.handleReturnData = function(data) {
		var h = '<dl>';
		for (j=0; j < data.length; j++) {
			h += '<dt class="vdClosed" onClick="vdDebug.toggleDL(this);">'+
				'<img src="'+this.imgPlus.src+'" />'+
				data[j][0].replace(/>/g,'&gt;')
				+'</dt><dd class="vdClosed">'+
				data[j][1].replace(/</g,'&lt;')+
				'</dd>';
		}
		h += '</dl>';
		return h;

	}

	this.dumpData = function(data) {
		if (data == null) {
			return "<i>undefined</i>";
		}
		else if (data.constructor == Object) {
			var h = '{<ul>\n';
			for (var key in data) {
				h += '<li class="vdOpen"><span onClick="vdDebug.toggleUL(this);">'+
					key + ' =></span> ' + this.dumpData(data[key]) +
					'</li>\n';
			}
			h += '</ul>}\n';
			return h;
		}
		else if (data.constructor == Array) {
			var h = '[<ul>\n';
			for (var j=0; j < data.length; j++) {
				h += '<li class="vdOpen"><span onClick="vdDebug.toggleUL(this);">'+
					this.dumpData(data[j])+'</span>'+
					'</li>\n';
			}
			h += '</ul>]\n';
			return h;
		}
		else {
			return data;
		}
	}

	this.handleDisplay = function(rawdata) {
		var data = this.parse(rawdata);
		console.log(data);

		var h;
		if (data.value == null || 
			data.value.length <= 0
			// || typeof (data.value.length) == "undefined" 

			) {

			h = "<i>(empty)</i>";
		}
		else {
			if (data.constructor == Object) {
				switch (data.key) {
					case 'vd_profile':     h = this.handleTable(     data.value); break;
					case 'vd_debug':       h = this.handleDebug(     data.value); break;
					//case 'vd_return_data': h = this.handleReturnData(data.value); break;
					default:               h = this.dumpData(        data.value); break;
				}
			}
			else {
				h = "<span>"+data+"</span>";
			}
		}
		console.log(h);

		document.getElementById(data.key).innerHTML = h;
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
		}
		else {
			obj.parentNode.className = "vdOpen";
			obj.firstChild.src=this.imgMinus.src;
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
					'app_id='     +this.app_id+
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

	//////////////////////////////////////////////////////////////////////////////////
	// Start of JSON library.
	// The stringify function and it's supporting functions have been removed
	// since this object only needs the parse function.
	// The comments were extremly verbose and have been removed.
	//////////////////////////////////////////////////////////////////////////////////
	this.f = function (n) {
		return n<10?'0'+n:n;
	}
	if (typeof Date.prototype.toJSON !== 'function') {
		Date.prototype.toJSON = function(key) {
			return this.getUTCFullYear()+'-'+f(this.getUTCMonth()+1)+'-'+f(this.getUTCDate())+'T'+f(this.getUTCHours())+':'+f(this.getUTCMinutes())+':'+f(this.getUTCSeconds())+'Z';
		}
		String.prototype.toJSON = Number.prototype.toJSON = Boolean.prototype.toJSON = function (key) {
			return this.valueOf();
		}
	}
	var cx=/[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,escapeable=/[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,gap,indent,meta={'\b':'\\b','\t':'\\t','\n':'\\n','\f':'\\f','\r':'\\r','"':'\\"','\\':'\\\\'},rep;

	this.parse = function(text,reviver) {
		var j;
		function walk(holder,key) {
			var k,v,value = holder[key];
			if (value&&typeof value==='object') {
				for (k in value) {
					if (Object.hasOwnProperty.call(value,k)) {
						v = walk(value,k);
						if (v!==undefined) {
							value[k]=v;
						}
						else {
							delete value[k];
						}
					}
				}
			}
			return reviver.call(holder,key,value);
		}
		cx.lastIndex=0;
		if (cx.test(text)) {
			text=text.replace(cx,
				function(a) {
					return '\\u'+('0000'+a.charCodeAt(0).toString(16)).slice(-4);
				}
			);
		}
		if (/^[\],:{}\s]*$/.test(text.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,'@').replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,']').replace(/(?:^|:|,)(?:\s*\[)+/g,''))) {
			j = eval('('+text+')');
			return typeof reviver==='function'?walk({'':j},''):j;
		}
		throw new SyntaxError('voodooDebug.parse');
	}
	//////////////////////////////////////////////////////////////////////////////////
	// End of JSON library
	//////////////////////////////////////////////////////////////////////////////////
}
