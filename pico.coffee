###
  pico is dscape/nano's little brother
  (c) 2012 Stephane Alnet
###

## pico.request
# pico.request is mikeal/request extended with a prefix URI that
# is automatically prepended to any URI.
request = require 'request'
byline = require 'byline'

pico_request = (base_uri) ->

  # FIXME prefix should support url.parse output.
  prefix = (uri) -> base_uri + if uri? and uri isnt '' then '/'+uri else ''

  # This is a variant on "function request(uri,options,callback)" in mikeal/request/main.js
  # We support undefined URI.
  def = (method) ->
    return (args...) ->
      if args.length > 0 and typeof args[0] is 'string'
        uri       = args.shift()
      if args.length > 0 and typeof args[0] is 'object'
        options   = args.shift()
      if args.length > 0 and typeof args[0] is 'function'
        callback  = args.shift()
      if args.length > 0
        throw new Error "Unexpected #{typeof args[0]} parameter"

      options ?= {}

      uri ?= options.uri
      if uri?
        options.uri = prefix uri
      else
        options.uri = prefix ''

      if callback?
        options.callback = callback

      method options

  result = def request
  result.get  = def request.get
  result.post = def request.post
  result.put  = def request.put
  result.head = def request.head
  result.del  = def request.del
  result.prefix = prefix
  return result

## pico
# pico builds on pico_request (and therefor request) and provides
# CouchDB-oriented methods.
# The pico request object is available as @request.
pico = (base_uri,user,pass) ->

  if user?
    pass ?= ''
    url = require 'url'
    parsed = url.parse base_uri
    parsed.auth = [user,pass].join(':')
    # This should no longer be needed with recent versions of Node.js
    delete parsed.href
    delete parsed.host
    #
    base_uri = url.format parsed

  qs = require 'querystring'

  couch_cb = (callback) ->
    if callback then (e,r,b) ->
      if e then return callback e, r, b
      if 200 <= r.statusCode < 300
        callback e, r, b
      else
        e = status:r.statusCode
        callback e, r

  head_cb = (callback) ->
    if callback then couch_cb (e,r,b) ->
      if e
        callback e, r
      else
        callback e, r, ok:true, rev:r?.headers?.etag?.replace /"/g, ''

  result = {}
  result.request = pico_request base_uri

  result.create = -> result.request.put arguments...
  result.destroy = -> result.request.del arguments...

  user_id = (name) -> 'org.couchdb.user:' + name

  ## get
  #     get(id,options,function(error,response,json))
  # Returns the document identified by id. Note that the revision is then {_rev:etag}.
  result.get = (id,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri = qs.escape(id)
    options.json = true
    @request.get options, couch_cb callback

  result.retrieve = ->
    console.warn "pico.retrieve is now pico.get"
    @get arguments...

  result.get.user = (name,args...) -> @get user_id(name), args...

  ## rev
  #     rev(id,options,function(error,response,{rev:etag}))
  # Returns the latest rev for the document identified by id.
  result.rev = (id,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri = qs.escape(id)
    @request.head options, head_cb callback

  result.rev.user = (name,args...) -> @rev user_id(name), args...

  ## put
  #     update(doc,options,function(error,response,json))
  # Creates or updates the document. The json object might contain {rev:etag} if the operation was successful.
  result.put = (doc,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri = qs.escape doc._id
    if doc._rev?
      options.qs ?= {}
      options.qs.rev = doc._rev
    options.json = doc
    @request.put options, couch_cb callback

  result.update = ->
    console.warn "pico.update is now pico.put"
    @put arguments...

  result.put.user = (name,args...) -> @put user_id(name), args...

  ## remove
  #     remove(doc,options,function(error,response,json))
  # Deletes the document. The json object might contain {rev:etag} if the operation was successful.
  result.remove = (doc,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri = qs.escape doc._id
    options.qs ?= {}
    options.qs.rev = doc._rev
    options.json = true
    @request.del options, couch_cb callback

  result.remove.user = (name,args...) -> @remove user_id(name), args...

  ## view
  #     view(design,view,options,function(error,response,json))
  # Run a view query.
  result.view = (design,view,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri = '_design/'+qs.escape(design)+'/_view/'+qs.escape(view)
    options.json = true
    @request.get options, couch_cb callback

  ## monitor
  #     monitor([params,]function(doc))
  # Continuously monitors database changes.
  # The callback is ran every time a document is updated.
  # The params hash may contain: filter_name, filter_params (a hash), since, since_name.
  # `since_name` is used to store the last retrieved sequence number on the server, so
  # that monitor can restart there next time it is called.

  monit_handler = (params,callback) ->
    # Create the query
    query =
      feed: 'continuous'
      heartbeat: 10000
      include_docs: true

    query.filter = params.filter_name if params.filter_name?
    query.since  = params.since       if params.since?
    if params.filter_params?
      query[k] = v for k, v of params.filter_params

    # Start the client request
    options =
      uri: '_changes?' + qs.stringify query
      jar: false
      json: true

    stream = @request.get options, (e) ->
      if e? then console.log e

    options = undefined
    stream = byline stream

    # Automatically restart if the client terminates
    stream.on 'end', ->
      stream = undefined
      result.monitor params, callback

    # Client parser
    stream.on 'data', (line) =>
      try
        p = JSON.parse line
      if p?.doc?
        callback p.doc
        if params.since_name?
          @request.get "_local/#{params.since_name}", json: true, (e,r,t) =>
            q =
              _id: "_local/#{params.since_name}"
              since: p.seq
            q._rev = t._rev if t?
            @request.put "_local/#{params.since_name}", json: q

  result.monitor = (params,callback) ->
    args = arguments
    if typeof params is 'function' and not callback? then [params,callback] = [{},params]

    if params.since_name?
      @request.get "_local/#{params.since_name}", json:true, (e,r,p) =>
        if p?.since?
          params.since = p.since
        monit_handler.apply @, [params,callback]
    else
      monit_handler.apply @, [params,callback]

    return

  # Compact a database
  result.compact = (cb) ->
    @request.post '_compact', json:{}, cb

  return result

module.exports = pico
pico.request = pico_request
pico.replicate = require './replicate'

# Request-compatible callback that log errors
# for operations.
pico._log = console.log
# Request-compatible callback that log errors
# for CouchDB operations.
pico.log = (e,r,b) ->
  if e?
    pico._log e
  else
    if not b?
      pico.log 'Missing body'
    else
      if not b.ok
        pico._log b


## Tests
# Tests for pico_request
pico_request_test = (object) ->
  assert = require 'assert'

  assert.strictEqual typeof object, 'function', "not a function"
  assert.strictEqual typeof object('http://example.net'), 'function', "does not return a function"
  assert.strictEqual typeof object('http://example.net').prefix, 'function', "prefix is not a function"
  assert.strictEqual object('http://example.net').prefix(''), 'http://example.net'
  assert.strictEqual object('http://example.net').prefix('foo'), 'http://example.net/foo'
  assert.strictEqual typeof object('http://example.net').get, 'function', "get is not a function"
  assert.strictEqual typeof object('http://example.net').post, 'function', "post is not a function"
  assert.strictEqual typeof object('http://example.net').put, 'function', "put is not a function"
  assert.strictEqual typeof object('http://example.net').head, 'function', "head is not a function"
  assert.strictEqual typeof object('http://example.net').del, 'function', "del is not a function"

  debug = false
  http = require 'http'
  method_server = http.createServer (req,res) ->
    console.dir arguments  if debug
    if req.method isnt 'HEAD'
      res.end req.method
    else
      res.end ''
  method_server.listen 1337, '127.0.0.1'
  attempts = 5
  conclude = ->
    attempts--
    if attempts is 0
      method_server.close()
  object('http://127.0.0.1:1337').get 'foo', (e,r,b) ->
    assert.strictEqual b, 'GET', "GET method failed"
    do conclude
  object('http://127.0.0.1:1337').post 'foo', (e,r,b) ->
    assert.strictEqual b, 'POST', "POST method failed"
    do conclude
  object('http://127.0.0.1:1337').put 'foo', (e,r,b) ->
    assert.strictEqual b, 'PUT', "PUT method failed"
    do conclude
  object('http://127.0.0.1:1337').del 'foo', (e,r,b) ->
    assert.strictEqual b, 'DELETE', "DELETE method failed"
    do conclude
  object('http://127.0.0.1:1337').head 'foo', (e,r,b) ->
    assert.strictEqual b, undefined, "HEAD method failed"
    do conclude
  # We support undefined URI.
  object('http://127.0.0.1:1337').get (e,r,b) ->
    assert.strictEqual b, 'GET', "short GET method failed"
    do conclude
  object('http://127.0.0.1:1337').post (e,r,b) ->
    assert.strictEqual b, 'POST', "short POST method failed"
    do conclude
  object('http://127.0.0.1:1337').put (e,r,b) ->
    assert.strictEqual b, 'PUT', "short PUT method failed"
    do conclude
  object('http://127.0.0.1:1337').del (e,r,b) ->
    assert.strictEqual b, 'DELETE', "short DELETE method failed"
    do conclude
  object('http://127.0.0.1:1337').head (e,r,b) ->
    assert.strictEqual b, undefined, "short HEAD method failed"
    do conclude

pico.request.test = ->
  console.log "Starting pico_request tests"
  pico_request_test pico_request

# Tests for pico
pico.test = ->

  object = pico

  assert = require 'assert'
  # .request must pass all tests for pico_request
  console.log "Starting pico.request tests"
  pico_request_test object.request
  console.log "Starting pico tests"
  assert.strictEqual typeof object('http://example.net').get, 'function', "get is not a function"
  assert.strictEqual typeof object('http://example.net').put, 'function', "put is not a function"
  assert.strictEqual typeof object('http://example.net').rev, 'function', "rev is not a function"
  assert.strictEqual typeof object('http://example.net').remove, 'function', "remove is not a function"
  assert.strictEqual typeof object('http://example.net').view, 'function', "view is not a function"
  assert.strictEqual typeof object('http://example.net').monitor, 'function', "monitor is not a function"

  db = pico 'http://127.0.0.1:5984/foo'
  db.destroy (e,r,b) ->
    db.create (e) ->
      assert.strictEqual e, null
      db.put {_id:'foo',bar:'babar'}, (e) ->
        assert.strictEqual e, null
        db.get 'foo', (e,r,b) ->
          assert.strictEqual e, null
          assert.strictEqual b.bar, 'babar'
          db.destroy (e) ->
            assert.strictEqual e, null
            console.log 'Done.'
