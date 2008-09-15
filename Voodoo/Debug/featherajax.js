//Created by Sean Kane (http://celtickane.com/programming/code/ajax.php)
//Feather Ajax v1.0.1

function AjaxObject101() {
	this.createRequestObject = function() {
		try {
			var ro = new XMLHttpRequest();
		}
		catch (e) {
			var ro = new ActiveXObject("Microsoft.XMLHTTP");
		}
		return ro;
	}
	this.sndReq = function(action, url, data) {
		if (action.toUpperCase() == "POST") {
			this.http.open(action,url,true);
			this.http.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
			this.http.onreadystatechange = this.handleResponse;
			this.http.send(data);
		}
		else {
			this.http.open(action,url + '?' + data,true);
			this.http.onreadystatechange = this.handleResponse;
			this.http.send(null);
		}
	}
	this.handleResponse = function() {
		if ( me.http.readyState == 4) {
			if (typeof me.funcDone == 'function') { me.funcDone();}
			console.log(JSON.parase(me.http.responseText));
			return;

			var rawdata = me.http.responseText.split("|");
			for ( var i = 0; i < rawdata.length; i++ ) {
				var item = (rawdata[i]).split("=>");
				if (item[0] != "") {
					if (item[1].substr(0,3) == "%V%" ) {
						document.getElementById(item[0]).value = item[1].substring(3);
					}
					else {
						document.getElementById(item[0]).innerHTML = item[1];
					}
				}
			}
		}
		if ((me.http.readyState == 1) && (typeof me.funcWait == 'function')) { me.funcWait(); }
	}
	var me = this;
	this.http = this.createRequestObject();
	
	var funcWait = null;
	var funcDone = null;
}
