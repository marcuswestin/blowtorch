var parseUrl = require('url').parse
var request = require('request')

module.exports = {
	setup:setup
}

function setup(app) {
	app.get('/BTImage/fetchImage', function(req, res) {
		var params = parseUrl(req.url, true).query
		delete req.headers.host
		console.log("BTImage.fetchImage", params.url)
		request({ url:params.url, headers:req.headers, method:req.method, timeout:5000 }, function(err, response, body) {
			if (err) {
				console.log("BTImage.fetchImage error", err)
				res.writeHead(err.code == 'ETIMEDOUT' ? 408 : 500)
				res.end()
			}
		}).pipe(res)
	})
}
