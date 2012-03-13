#!/usr/local/bin/node

var exec = require('child_process').exec,
	path = require('path')

if (!process.argv[2]) {
	console.error('missing file argument')
	return process.exit(-1)
}

var buildSrc = path.join(process.cwd(), process.argv[2]),
	buildDir = path.join(__dirname, '../builds'),
	buildName = 'blowtorch-'+new Date().getTime(),
	buildTarget = path.join(buildDir, buildName+'.tar')

var command = [
	'mkdir -p '+buildDir,
	'cp -r '+buildSrc+' /tmp/'+buildName,
	'cd /tmp/',
	'tar cf '+buildTarget+' '+buildName].join(' && ')
exec(command, function(err) {
	if (err) { return handleError(err) }
	console.log('done building', buildTarget)
})

function handleError(err) {
	console.log("error", err)
	process.exit(-1)
}
