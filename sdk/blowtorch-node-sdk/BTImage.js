var parseUrl = require('url').parse
var request = require('request')

module.exports = {
	setup:setup
}

var cache = {}

function setup(app) {
	app.get('/BTImage/fetchImage', function(req, res) {
		var params = parseUrl(req.url, true).query
		delete req.headers.host
		if (cache[params.url]) {
			console.log("BTImage.fetchImage found in cache", params.url)
			res.writeHead(200, cache[params.url].headers)
			res.end(cache[params.url].body)
		} else {
			console.log("BTImage.fetchImage", params.url)
			request({ url:params.url, headers:req.headers, method:req.method, timeout:5000, encoding:null }, function(err, response, body) {
				if (err || res.statusCode >= 300) {
					console.log("BTImage.fetchImage error", err)
					res.writeHead(err.code == 'ETIMEDOUT' ? 408 : 500)
					res.end()
				} else {
					cache[params.url] = { headers:response.headers, body:body }
					res.writeHead(response.statusCode, response.headers)
					res.end(body)
				}
			})
		}
	})
}
