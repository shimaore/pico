# replicate.coffee
# (c) 2012 Stephane Alnet
# Initiate replication.

request = require 'request'
couchdb_rewrite_url = require './couchdb_rewrite_url'

# use the standard replicator (_replicator will not recover)
replicator = 'http://127.0.0.1:5984/_replicate'

log_error = (e) -> if e? then console.log e

## replicate( source_uri, target_uri )
# Initiate continuous replication from the source to the target.
# The replication is restarted if it fails (as long as the node.js code
# is running).
replicate = (source_uri,target_uri,replicate_interval,filter,params) ->

  if not source_uri?
    console.log "source_uri is required, not replicating"
    return
  if not target_uri?
    console.log "target_uri is required, not replicating"
    return

  start_replication = ->

    replicant =
      # _id:    'some_id'   # Only when using _replicator
      source: couchdb_rewrite_url source_uri
      target: couchdb_rewrite_url target_uri
      continuous: true
    replicant.filter = filter if filter?
    replicant.query_params = params if params?

    request.post replicator, {json:replicant}, log_error

  # The replicator tends to die randomly, so restart it at regular intervals.
  minutes = 60 * 1000
  default_replicate_interval = 5 * minutes

  replicate_interval ?= default_replicate_interval

  # Start replication and re-start it at intervals
  start_replication()
  setInterval start_replication, replicate_interval

module.exports = replicate
