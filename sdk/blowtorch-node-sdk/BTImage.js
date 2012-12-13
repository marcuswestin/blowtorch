var parseUrl = require('url').parse
var request = require('request')
var imagemagick = require('imagemagick')

module.exports = {
	setup:setup
}

var cache = {}

function setup(app) {
	app.get('/BTImage/fetchImage', function(req, res) {
		var params = parseUrl(req.url, true).query
		if (cache[params.url]) {
			console.log("BTImage.fetchImage found in cache", params.url)
			send(res, params, cache[params.url])
		} else {
			delete req.headers.host
			delete req.headers['cache-control']
			request({ url:params.url, headers:req.headers, method:req.method, timeout:5000, encoding:null }, function(err, response, data) {
				if (err || res.statusCode >= 300) {
					console.log("BTImage.fetchImage error", err)
					res.writeHead(err.code == 'ETIMEDOUT' ? 408 : 500)
					res.end()
				} else {
					if (!data) { throw new Error("Got no data from Facebook") }
					var result = { headers:response.headers, data:data }
					if (params.cache) { cache[params.url] = result }
					send(res, params, result)
				}
			})
		}
	})
}

function send(res, params, result) {
	var data = result.data
	
	function doSend(data) {
		each(['content-length', 'cache-control', 'expires', 'date'], function(header) {
			delete result.headers[header]
		})
		if (params.mimeType) {
			result['content-type'] = params.mimeType
		}
		res.writeHead(200, result.headers)
		res.end(data)
	}
	
	if (params.resize) {
		resizeImage(data, params.resize, doSend)
	} else {
		doSend(data)
	}
}

function resizeImage(data, resize, callback) {
	// resize == '120x400'
	var customArgs = [
		"-gravity", "center",
		"-extent", resize
	]
	
	var sizes = resize.split('x')
	
	imagemagick.resize({
		srcData: data,
		strip: false,
		width: sizes[0],
		height: sizes[1]+'^',
		customArgs: customArgs
	}, function(err, stdout, stderr) {
		if (err) { throw err }
		callback(new Buffer(stdout, 'binary'))
	})
}
