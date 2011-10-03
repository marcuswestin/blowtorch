#!/usr/local/bin/node

var path = require('path'),
	requireServer = require('require/server'),
	appPath = path.resolve(process.cwd(), process.argv[2])

requireServer.addPath('dom', __dirname+'/../node_modules/dom/') // for BlowTorch apps. TODO Stop doing this
requireServer.addPath('std', __dirname+'/../node_modules/std/')
requireServer.addPath('blowtorch', __dirname+'/../js/')
requireServer.addFile('app', appPath)

requireServer.listen(3333)