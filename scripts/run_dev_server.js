#!/usr/local/bin/node

var requireServer = require('require/server')

requireServer.addPath('blowtorch', __dirname+'/../js/')

requireServer.listen(3333)