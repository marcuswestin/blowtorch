#!/usr/local/bin/node

var path = require('path'),
	requireServer = require('require/server'),
	appPath = path.resolve(process.cwd(), process.argv[2])

requireServer.addPath('blowtorch', __dirname+'/../js/')
requireServer.addFile('app', appPath)

requireServer.listen(3333)