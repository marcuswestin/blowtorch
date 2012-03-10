#!/usr/local/bin/node

var http = require('http'),
	fs = require('fs'),
	uuid = require('uuid'),
	path = require('path')

var port = 4000
http.createServer(handleRequest).listen(port)
console.log('running on port', port)

function handleRequest(req, res) {
	var url = req.url,
		method = req.method,
		match
	if (method == 'POST' && (match = url.match(/^\/upgrade/))) {
		handleUpgradeRequest(req, res)
	} else if (method == 'GET' && (match = url.match(/^\/builds\/([-_a-zA-Z0-9]*)/))) {
		handleVersionDownloadRequest(req, res, match[1])
	} else {
		handle404(req, res)
	}
}

function handle404(req, res) {
	console.log(404, req.method, req.url)
	var message = 'not found'
	res.writeHead(404, { 'Content-Length':message.length })
	res.end(message)
}

var currentVersion = fs.readdirSync(__dirname+'/../builds')[0].split('.')[0]
function handleUpgradeRequest(req, res) {
	parseJsonPostBody(req, function(err, reqObj) {
		if (err) { return sendError(res, err) }
		console.log('upgrade request', reqObj)

		var client_info = reqObj.client_info || {},
			resObj = { client_info:client_info }
		if (!client_info.client_id) {
			client_info.client_id = uuid.v1()
		}
		if (!client_info.current_version) {
			resObj.new_version = currentVersion
		}
		
		console.log('upgrade response', resObj)
		send(res, JSON.stringify(resObj), 'application/json')
	})
}

function handleVersionDownloadRequest(req, res, version) {
	console.log('download request', version, path.join(__dirname, '../builds', version+'.tar'))
	fs.readFile(path.join(__dirname, '../builds', version+'.tar'), function(err, content) {
		if (err) { return sendError(res, err) }
		send(res, content, 'application/x-tar')
		console.log('download response sent', version)
	})
}

// Util
function parseJsonPostBody(post, callback) {
	var postData = ''
	post.on('error', function(error) {
		callback(error, null)
	})
	post.on('data', function(chunk) {
		postData += chunk
		if (postData.length > 1e6) {
			callback(new Error('POST body is too big'), null)
			request.connection.destroy()
		}
	})
	post.on('end', function() {
		try { callback(null, JSON.parse(postData)) }
		catch(e) { callback(e, null) }
	})
}

function sendError(res, err) {
	var message = err.message || err
	res.writeHead(500, { 'Content-Length':message.length })
	res.end(message)
}

function send(res, data, contentType) {
	res.writeHead(200, { 'Content-Type':contentType, 'Content-Length':data.length })
	res.end(data)
}
