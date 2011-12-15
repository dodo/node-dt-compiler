fs = require 'fs'
jQuery = require 'jquery'
{ extname } = require 'path'
{ jsonify } = require './traverse'
link = require './linker'


class HTMLCompiler
    constructor: ->
        # new jquery context
        @$ = jQuery.create()
        @$.fn.compile = -> jsonify this
        # values
        @loaded = no
        @loading = no
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
        throw new Error "html file already loaded." if @loaded
        @loaded = yes
        @parse data

    load: (@filename, callback) ->
        @loading = []
        @read @filename, (err, data) ->
            return callback?.call(this, err) if err
            [loading, @loading] = [@loading, no]
            @use data
            delayed.call this, err for delayed in loading
            callback?(null, @el)

    open: (@filename) ->
        data = @readSync @filename
        return @use data

    compile: (el) ->
        throw new Error "no html file loaded or html string used." unless @loaded
        el ?= @el
        # return only the important information
        do el?.compile

    build: (opts = {}, selector) ->
        if typeof opts is 'string'
            opts = dest:opts
        # defaults
        opts.watch  ?= no
        opts.src    ?= @filename
        opts.dest   ?= null # it's ok when undefined
        opts.select ?= selector
        opts.error  ?= (e) -> console.error e?.stack or e
        opts.done   ?= null
        # values
        pending = no
        elem = data:[]
        elem.data = @compile(opts.select?.call this) if @loaded
        # when file is ready to be updated again
        done = ->
            # allow to use build like load
            opts.done?()
            # only invoke callback once (not on every fs cahnge again)
            delete opts.done
            pending = no
        # compile dom to json and update opts.dest file
        reload = (err) =>
            opts.error(err) if err?
            # this updates all template linked to this design.
            # the next time a linked template is invoked it will use
            # automagicly the new data because elem doesn't change.
            elem.data = @compile opts.select?.call this
            unless opts.dest?
                done()
            else
                # save json dom in an own file
                ext = extname(opts.dest).toLowerCase()
                if ext is '.json'
                    source = JSON.stringify(elem.data)
                else if ext is '.js'
                    source = """var link = require('dynamictemplate/linker'),
                    tree = #{JSON.stringify elem.data};
                    module.exports = function (rawtemplate) {
                        return link(rawtemplate, tree);
                    };"""
                else
                    throw new Error "file extendsion of #{opts.dest} not supported."
                fs.writeFile(opts.dest, source, done)

        # do an auto load if not loaded so an extra load call is not needed
        @load opts.src, reload  if opts.src? and not (@loading or @loaded)
        @loading.push reload if @loading

        if opts.watch
            # this is the filesystem listen routine
            watcher = (curr, prev) ->
                return if pending
                pending = yes
                if curr.mtime isnt prev.mtime
                    # modified, wait a little before reloading
                    # since modifications tend to come in waves
                    setTimeout ( ->
                        try
                            do reload
                        catch err
                            opts.error(err)
                    ), 11
            # no listen on fielsystem for changes
            if typeof opts.watch is 'object'
                fs.watchFile(opts.src, opts.watch, watcher)
            else
                fs.watchFile(opts.src, watcher)
        # done
        return elem

# exports

module.exports = HTMLCompiler

