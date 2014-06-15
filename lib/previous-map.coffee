base64js = require('base64-js')
mozilla  = require('source-map')
path     = require('path')
fs       = require('fs')

class PreviousMap
  constructor: (root, opts) ->
    @file = opts.from

    @loadAnnotation(root)
    @inline = @startWith(@annotation, '# sourceMappingURL=data:')

    text  = @loadMap(opts)
    @text = text if text

  # Return SourceMapConsumer object to read map
  consumer: ->
    @consumerCache ||= new mozilla.SourceMapConsumer(@text)

  # Is map has sources content
  withContent: ->
    @consumer().sourcesContent?.length > 0

  # Is `string` is starting with `start`
  startWith: (string, start) ->
    return false unless string
    string[0..start.length-1] == start

  # Load for annotation comment from previous compilation step
  loadAnnotation: (root) ->
    last = root.last
    return unless last

    if last.type == 'comment' and @startWith(last.text, '# sourceMappingURL=')
      @annotation = last.text

  # Encode different type of inline
  decodeInline: (text) ->
    uri    = '# sourceMappingURL=data:application/json,'
    base64 = '# sourceMappingURL=data:application/json;base64,'

    if @startWith(text, uri)
      decodeURIComponent( text[uri.length..-1] )

    else if @startWith(text, base64)
      text  = text[base64.length..-1]
      bytes = base64js.toByteArray(text)
      (String.fromCharCode(byte) for byte in bytes).join('')

    else
      encoding = text.match(/ata:application\/json;([^,]+),/)?[1]
      throw new Error("Unsupported source map encoding #{ encoding }")

  # Load previous map
  loadMap: (opts) ->
    if opts.map and typeof(opts.map) != 'boolean'
      if typeof(opts.map) == 'string'
        opts.map
      else if opts.map instanceof mozilla.SourceMapConsumer
        mozilla.SourceMapGenerator.fromSourceMap(opts.map).toString()
      else if opts.map instanceof mozilla.SourceMapGenerator
        opts.map.toString()
      else if typeof(opts.map) == 'object' and opts.map.version?
        JSON.stringify(opts.map)
      else
        throw new Error("Unsupported previous source map format: #{ opts.map }")

    else if @inline
      @decodeInline(@annotation)

    else if @file
      if @annotation
        file = @annotation.replace('# sourceMappingURL=', '')
        map  = path.join(path.dirname(@file), file)
      else
        map  = @file + '.map'

      fs.readFileSync(map).toString() if fs.existsSync?(map)

module.exports = PreviousMap
