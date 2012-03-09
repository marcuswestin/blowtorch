#!/usr/local/bin/node

var http = require('http'),
	fs = require('fs')

var port = 4000
http.createServer(handleRequest).listen(port)
console.log('running on port', port)

function handleRequest(req, res) {
	// if (req.method != 'POST') {
	// 	handle404(req, res)
	// 	return
	// }
	
	var url = req.url, match
	console.log(url)
	if (match = url.match(/^\/upgrade/)) {
		handleUpgradeRequest(req, res)
	} else if (match = url.match(/^\/version\/([_a-zA-Z0-9]*)/)) {
		handleVersionDownloadRequest(req, res, match[1])
	} else {
		handle404(req, res)
	}
}

function handle404(req, res) {
	var message = 'not found'
	res.writeHead(404, { 'Content-Length':message.length })
	res.end(message)
}

var versions = ['']
var currentVersion = 'version_x'
function handleUpgradeRequest(req, res) {
	parsePostBody(req, function(err, requestData) {
		if (err) { return sendError(res, err) }
		console.log("handleUpgradeRequest", requestData)
		sendJson(res, { client_id:'xyz', new_version:currentVersion })
	})
}

function handleVersionDownloadRequest(req, res, version) {
	console.log("version download request", requestContent)
	return
	var requestData = JSON.parse(requestContent.toString())
	fs.readFile(__dirname+'/payloads/hello.html', function(err, content) {
		sendHtml(res, content)
	})
}

// Util
function parsePostBody(post, callback) {
	var postData = ''
	post.on('error', function(error) { callback(error, null) })
	post.on('end', function() { callback(null, postData) })
	post.on('data', function(chunk) {
		postData += chunk
		if (postData.length > 1e6) {
			callback(new Error('POST body is too big'), null)
			request.connection.destroy()
		}
	})
}

function sendError(res, err) {
	var message = err.message || err
	res.writeHead(500, { 'Content-Length':message.length })
	res.end(message)
}

function sendJson(res, data) {
	var response = JSON.stringify(data)
	res.writeHead(200, { 'Content-Type':'application/json', 'Content-Length':response.length })
	res.end(response)
}

function sendHtml(res, data) {
	res.writeHead(200, { 'Content-Type':'text/html', 'Content-Length':data.length })
	res.end(data)
}