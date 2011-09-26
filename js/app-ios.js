var app = require('app'),
	bind = require('std/bind'),
	appDiv = document.body.appendChild(document.createElement('div'))

document.body.style.margin = 0
document.body.style.height = '100%'
document.documentElement.style.height = '100%'

appDiv.style.marginTop = '0px'
appDiv.style.background = 'red'
appDiv.style.height = '100%'

if (window.WebViewJavascriptBridge) { app.startApp(appDiv) }
else { document.addEventListener('WebViewJavascriptBridgeReady', bind(app, app.startApp, appDiv)) }
