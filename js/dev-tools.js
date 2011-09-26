if (window.WebViewJavascriptBridge) { initDevTools() }
else { document.addEventListener('WebViewJavascriptBridgeReady', initDevTools) }

function initDevTools() {
	window.onerror = function(e) { alert('error: ' + e)};

	var el = document.body.appendChild(document.createElement('div'));
	el.style.position = 'absolute';
	el.style.top = '20px';
	el.style.right = 0;
	el.style.padding = '5px';
	el.style.background = '#ccf';
	el.innerHTML = 'R';
	el.ontouchstart = function() { WebViewJavascriptBridge.sendMessage('dev:reload') }
}
