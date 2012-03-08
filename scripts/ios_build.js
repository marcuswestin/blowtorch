#!/usr/local/bin/node

var path = require('path'),
	requireCompiler = require('require/compiler'),
	appPath = path.resolve(process.cwd(), process.argv[2]),
	fs = require('fs')

requireCompiler.addPath('dom', __dirname+'/../node_modules/dom/') // for BlowTorch apps. TODO Stop doing this
requireCompiler.addPath('std', __dirname+'/../node_modules/std/')
requireCompiler.addPath('blowtorch', __dirname+'/../js/')
requireCompiler.addFile('app', appPath)

var buildFile = appPath + '.ios-build'
console.log('building to', buildFile, '...')
fs.writeFileSync(buildFile, requireCompiler.compile(__dirname + '/../js/bootstrap-ios'))
console.log("done!")
