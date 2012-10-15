var parseUrl = require('url').parse
var request = require('request')

module.exports = {
	setup:setup
}

function setup(app) {
	app.get('/BTImage/fetchImage', function(req, res) {
		var params = parseUrl(req.url, true).query
		delete req.headers.host
		request({ url:params.url, headers:req.headers, method:req.method }).pipe(res)
	})
}
