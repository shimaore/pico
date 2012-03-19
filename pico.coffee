###
  pico is dscape/nano's little brother
  (c) 2012 Stephane Alnet
###

## pico.request
# pico.request is mikeal/request extended with a prefix URI that
# is automatically prepended to any URI.
request = require 'request'

pico_request = (base_uri) ->

  # FIXME prefix should support url.parse output.
  prefix = (uri) -> base_uri + if uri? and uri isnt '' then '/'+uri else ''

  # This is a variant on "function request(uri,options,callback)" in mikeal/request/main.js
  def = (method) ->
    (uri,options,callback) ->
      if typeof options is 'function' and not callback
        callback = options
      if typeof options is 'object'
        options.uri = prefix uri
      else
        if typeof uri is 'string'
          options = uri: prefix uri
        else
          options = uri
          options.uri = prefix options.uri
      if callback
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
pico = (base_uri) ->

  qs = require 'querystring'

  def_cb = (callback) ->
    if callback then (e,r,b) ->
      if e then return callback e, r, b
      unless 200 <= r.statusCode < 300
        e = error:r.statusCode
      callback e, r, b

  head_cb = (callback) ->
    if callback then (e,r,b) ->
      if e then return callback e, r, b
      unless 200 <= r.statusCode < 300
        e = error:r.statusCode
      callback e, r, ok:true, rev:r?.headers?.etag.replace /"/g, ''

  result = pico_request base_uri

  ## retrieve
  #     retrieve(id,options,function(error,response,json))
  # Returns the document identified by id. Note that the revision is then {_rev:etag}.
  result.retrieve = (id,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= qs.escape(id)
    options.json = true
    @get options, def_cb callback

  ## rev
  #     rev(id,options,function(error,response,{rev:etag}))
  # Returns the latest rev for the document identified by id.
  result.rev = (id,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= qs.escape(id)
    @head options, head_cb callback

  ## update
  #     update(doc,options,function(error,response,json))
  # Creates or updates the document. The json object might contain {rev:etag} if the operation was successful.
  result.update = (doc,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    if doc._rev?
      options.uri ?= qs.escape(doc._id)+'?rev='+doc._rev
    else
      options.uri ?= qs.escape(doc._id)
    options.json = doc
    @put options, def_cb callback

  ## remove
  #     remove(doc,options,function(error,response,json))
  # Deletes the document. The json object might contain {rev:etag} if the operation was successful.
  result.remove = (doc,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= qs.escape(doc._id)+'?rev='+doc._rev
    options.json = true
    @del options, def_cb callback

  ## view
  #     view(design,view,options,function(error,response,json))
  # Run a view query.
  result.view = (design,view,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= '_design/'+qs.escape(design)+'/_view/'+qs.escape(view)
    options.json = true
    @get options, def_cb callback

  return result

module.exports = pico
pico.request = pico_request

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

  http = require 'http'
  method_server = http.createServer (req,res) ->
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
    assert.strictEqual b, 'GET'
    do conclude
  object('http://127.0.0.1:1337').post 'foo', (e,r,b) ->
    assert.strictEqual b, 'POST'
    do conclude
  object('http://127.0.0.1:1337').put 'foo', (e,r,b) ->
    assert.strictEqual b, 'PUT'
    do conclude
  object('http://127.0.0.1:1337').del 'foo', (e,r,b) ->
    assert.strictEqual b, 'DELETE'
    do conclude
  object('http://127.0.0.1:1337').head 'foo', (e,r,b) ->
    assert.strictEqual b, ''
    do conclude

pico.request.test = ->
  console.log "Starting pico_request tests"
  pico_request_test pico_request

# Tests for pico
pico.test = ->
  console.log "Starting pico tests"
  # pico must pass all tests for pico_request
  pico_request_test pico

  object = pico

  assert = require 'assert'
  assert.strictEqual typeof object('http://example.net').retrieve, 'function', "retrieve is not a function"
  assert.strictEqual typeof object('http://example.net').update, 'function', "update is not a function"
  assert.strictEqual typeof object('http://example.net').rev, 'function', "rev is not a function"
  assert.strictEqual typeof object('http://example.net').update, 'function', "update is not a function"
  assert.strictEqual typeof object('http://example.net').remove, 'function', "remove is not a function"
  assert.strictEqual typeof object('http://example.net').view, 'function', "view is not a function"
