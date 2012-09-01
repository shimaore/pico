pico - A smaller CouchDB client for Node.js
-------------------------------------------

(c) 2012 Stephane Alnet

pico.request is mikeal/request extended with a prefix URI that
is automatically prepended to any URI.

    r = pico.request('http://127.0.0.1:5984/db')
    r.get('foo') // plain request method, no magic

pico builds on pico.request (and therefor request) and provides
CouchDB-oriented methods.

    r = pico('http://127.0.0.1:5984/db')
    r.request.get('foo') // pico.request method, no magic
    r.get('foo') // pico (CouchDB) method, some magic added

`get(id,options,function(error,response,json))`
Returns the document identified by id. Note that the revision is then `{_rev:etag}`.

`rev(id,options,function(error,response,{rev:etag}))`
Returns the latest rev for the document identified by id. The revision is `{rev:etag}`.

`put(doc,options,function(error,response,json))`
Creates or updates the document. The json object might contain `{rev:etag}` if the operation was successful.

`remove(doc,options,function(error,response,json))`
Deletes the document. The json object might contain `{rev:etag}` if the operation was successful.
