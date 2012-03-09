module.exports = {
	query: function(query, callback) { BlowTorch.send('SQL', { query:query }, callback) },
	update: function(update, callback) { BlowTorch.send('SQL', { update:update }, callback) }
}

