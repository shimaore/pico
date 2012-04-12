# couchdb_rewrite_url.coffee
# (c) 2011 Stephane Alnet
#
# Still a bug? CouchDB replication can't authenticate properly, the Base64 contains %40 litteraly...
#
## Returns either a string URL or request object that will properly authenticate with CouchDB
#  when used by the replication process.

couchdb_rewrite_url = (original) ->
  url = require 'url'
  qs = require 'querystring'
  parsed = url.parse original

  response = url.format
      protocol: parsed.protocol
      hostname: parsed.hostname
      port:     parsed.port
      pathname: parsed.pathname

  if not parsed.auth?
    # Simplify 'http://127.0.0.1:5984/database' into 'database'
    if parsed.protocol is 'http:' and parsed.hostname is '127.0.0.1' and parsed.port is '5984'
      return parsed.pathname.substr(1)
    # If no authentication is required the URL should work just fine.
    else
      return response

  # When authentication is required, rewrite the authentication token
  # into a header (since CouchDB replication does not unescape).
  [username,password] = parsed.auth.split /:/
  username = qs.unescape username if username?
  password = qs.unescape password if password?

  username ?= ''
  password ?= ''
  basic = new Buffer("#{username}:#{password}")
  response =
      url: response
      headers:
        "Authorization": "Basic #{basic.toString('base64')}"
  return response

## To run the tests: require('couchdb_rewrite_url').test()
couchdb_rewrite_url.test = ->
  assert = require 'assert'
  assert.strictEqual couchdb_rewrite_url('http://127.0.0.1:5984/bob'), 'bob'
  assert.strictEqual couchdb_rewrite_url('http://example.com:5984/bob'), 'http://example.com:5984/bob'
  assert.deepEqual couchdb_rewrite_url('http://foo:bar@example.com:5984/bob'), {
    url: 'http://example.com:5984/bob'
    headers:
      "Authorization": 'Basic Zm9vOmJhcg=='
  }
  yes

module.exports = couchdb_rewrite_url
