###
# (c) 2010 Stephane Alnet
# Released under the AGPL3 license
###

##  line_stream()
# Returns an in-memory, line-oriented, writable stream.
#
## Event: 'line'
# The line event is sent every time a full line is received.

module.exports = ->

  parser = new process.EventEmitter()
  parser.writable = true

  parser.buffer = ""

  process_buffer = ->
    d = parser.buffer.split("\n")
    while d.length > 1
      line = d.shift()
      parser.emit 'line', line
    parser.buffer = d[0]

  parser.write = (chunk,encoding) ->
    parser.buffer += chunk.toString(encoding)
    do process_buffer
    return true

  parser.end = (chunk,encoding) ->
    if chunk?
      parser.buffer += chunk.toString(encoding)
    do process_buffer
    # Flush the buffer
    on_line buffer if buffer?
    parser.destroy()

  parser.destroy = ->
    parser.writable = false

  return parser
