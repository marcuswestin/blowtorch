if (window.WebViewJavascriptBridge) { initDevTools() }
else { document.addEventListener('WebViewJavascriptBridgeReady', initDevTools) }

function initDevTools() {
	window.onerror = function(e) { alert('error: ' + e)};

	var el = document.body.appendChild(document.createElement('div'));
	el.style.position = 'fixed';
	el.style.top = 0;
	el.style.right = 0;
	el.style.height = el.style.width = '15px'
	el.style.textAlign = 'center'
	el.style.background = '#ccf'
	el.innerHTML = '-'
	el.onclick = function() { WebViewJavascriptBridge.sendMessage(JSON.stringify({ command:'blowtorch:reload' })) }
}


console.log = function() {
	var args = Array.prototype.slice.call(arguments, 0)
	WebViewJavascriptBridge.sendMessage(JSON.stringify({ command:'blowtorch:log', data:{ args:args } }))
}