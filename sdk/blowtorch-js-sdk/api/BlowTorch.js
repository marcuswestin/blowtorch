var unique = require('std/unique'),
	sql = require('./sql')

module.exports = {
	init: init,
	setMessageHandler: setMessageHandler,
	send: send,
	sql: sql,
	alert: BTAlert
}

var callbacks = {},
	messageHandler

function setMessageHandler(aMessageHandler) { messageHandler = aMessageHandler }

function send(command, data, callback) {
	var callbackID
	if (callback) {
		callbackID = unique()
		callbacks[callbackID] = callback
	}
	var message = JSON.stringify({
		command:command,
		data:data,
		callbackID:callbackID
	})
	WebViewJavascriptBridge.sendMessage(message)
}

function init(callback) {
	WebViewJavascriptBridge.setMessageHandler(function(messageJSON) {
		var message = JSON.parse(messageJSON),
			responseID = message.responseID,
			callback = callbacks[responseID]
		
		delete callbacks[responseID]
		callback(message.error, message.data)
	})
	callback()
}

function BTAlert() { alert(JSON.stringify(arguments)) }
