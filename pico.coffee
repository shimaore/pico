###
  pico is dscape/nano's little brother
  (c) 2012 Stephane Alnet
###

## pico.request
# pico.request is mikeal/request extended with a prefix URI that
# is automatically prepended to any URI.
class pico_request extends require 'request'
  constructor: (@base_uri) ->

  prefix: (uri) -> @base_uri + if uri? then '/'+uri else ''

  # This is a variant on "function request(uri,options,callback)" in mikeal/request/main.js
  def = (method) ->
    (uri,options,callback) ->
      if typeof options is 'function' and not callback?
        callback = options
      if typeof options is 'object'
        options.uri = @prefix uri
      else if typeof uri is 'string'
        options = @prefix uri
      else options = uri
      if callback
        options.callback = callback
        method options

  get:  def @get
  post: def @post
  put:  def @put
  head: def @head
  del:  def @del

## pico
# pico builds on pico_request (and therefor request) and provides
# CouchDB-oriented methods.
class pico extends pico_request

  request: pico_request

  qs = require 'querystring'

  def_cb = (callback) ->
    if callback then (e,r,b) ->
      unless error or 200 <= r.statusCode < 300
        e = error:r.statusCode
      callback e, r, b

  head_cb = (callback) ->
    if callback then (e,r,b) ->
      unless error or 200 <= r.statusCode < 300
        e = error:r.statusCode
      callback e, r, _rev:r?.headers?.etag

  ## retrieve
  #     retrieve(id,options,function(error,response,json))
  # Returns the document identified by id. Note that the revision is then {_rev:etag}.
  retrieve: (id,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= qs.escape(id)
    options.json = true
    @get options, def_cb callback

  ## rev
  #     rev(id,options,function(error,response,{rev:etag}))
  # Returns the latest rev for the document identified by id.
  rev:      (id,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= qs.escape(id)
    @head options, head_cb callback

  ## update
  #     update(doc,options,function(error,response,json))
  # Creates or updates the document. The json object might contain {rev:etag} if the operation was successful.
  update:   (doc,options,callback) ->
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
  remove:   (doc,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= qs.escape(doc._id)+'?rev='+doc._rev
    options.json = true
    @del options, def_cb callback

  view:     (design,view,options,callback) ->
    if typeof options is 'function' and not callback? then [options,callback] = [{},options]
    options ?= {}
    options.uri ?= '_design/'+qs.escape(design)+'/_view/'+qs.escape(view)
    @retrieve options, def_cb callback


module.exports = pico
