var el = document.body.appendChild(document.createElement('div'))
el.style.position = 'absolute'
el.style.top = '20px'
el.style.right = 0
el.style.padding = '5px'
el.style.background = '#ccf'
el.innerHTML = 'R'
document.addEventListener('WebViewJavascriptBridgeReady', function() {
	el.ontouchstart = function() { WebViewJavascriptBridge.sendMessage('dev:reload') }
})

