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
	var responseId
	if (callback) {
		responseId = unique()
		callbacks[responseId] = callback
	}
	var message = JSON.stringify({
		command:command,
		data:data,
		responseId:responseId
	})
	WebViewJavascriptBridge.sendMessage(message)
}

function init(callback) {
	WebViewJavascriptBridge.setMessageHandler(function(messageJSON) {
		var message = JSON.parse(messageJSON),
			responseId = message.responseId,
			callback = callbacks[responseId]
		delete callbacks[responseId]
		callback(message.error, message.data)
	})
	callback()
}

function BTAlert() { alert(JSON.stringify(arguments)) }
