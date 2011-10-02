var app = require('app'),
	bind = require('std/bind'),
	appDiv = document.body.appendChild(document.createElement('div'))

BlowTorch = require('./BlowTorch') // global

document.body.style.margin = 0
document.body.style.height = '100%'
document.documentElement.style.height = '100%'

appDiv.style.marginTop = '0px'
appDiv.style.background = 'red'
appDiv.style.height = '100%'

function start() {
	BlowTorch.init(function() {
		BlowTorch.body = appDiv
		app.startApp()
	})
}

if (window.WebViewJavascriptBridge) { start() }
else { document.addEventListener('WebViewJavascriptBridgeReady', start) }
