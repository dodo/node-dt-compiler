fs = require 'fs'
jQuery = require 'jquery'
{ jsonify } = require './traverse'


class HTMLCompiler
    constructor: ->
        # new jquery context
        @$ = jQuery.create()
        @$.fn.compile = -> jsonify this
        #aliases
        @loadSync = @open

    read: (filename, callback) ->
        fs.readFile filename, (err, data) =>
            callback?.call(this, err, data?.toString())

    readSync: (filename) ->
        fs.readFileSync(filename)?.toString()

    parse: (data) ->
        @el = @$(data)

    select: (from, to) ->
        # selector
        el = @el.find(from)
        # dont touch origin
        el = el.clone()
        # deselector
        el.find(to).remove()
        # rest
        return el

    use: (data) ->
        @loaded = yes
        @parse data

    load: (filename, callback) ->
        @read filename, (err, data) ->
            return callback.call(this, err) if err
            @use data
            callback(null, @el)

    open: (filename) ->
        data = @readSync filename
        return @use data

    compile: (el) ->
        throw new Error "no html file loaded or html string used." unless @loaded
        el ?= @el
        # return only the important information
        do el.compile
#         tree = jsonify el
#         r = suitup rawtemplate, tree
#         r.tree = tree
#         r

# exports

module.exports = HTMLCompiler
