if (window.WebViewJavascriptBridge) { startApp() }
else { document.addEventListener('WebViewJavascriptBridgeReady', startApp) }

function startApp() {
	document.body.appendChild(document.createElement('div')).innerHTML = '<br />HI ' + new Date().getTime()	
}
