fs = require 'fs'
render = require 'render'
mkdirp = require 'mkdirp'
{ extname, dirname, basename, join:pathjoin } = require 'path'
{ jsonify } = require './traverse'
link = require './linker'
$ = undefined

# https://github.com/brandonbloom/html2coffeekup
# TODO get compiler in browser running so its possible to apply a template onto existing dom elements

maybeDefer = (method, methargs..., callback) ->
    res = method?.apply(this, methargs)
    if typeof res is 'function'
        res.call this, methargs..., (args...) =>
            callback.apply(this, args)
    else
        callback.call(this, res)


extensions =  # defaults
    json: (tree) ->
        render.ctbn(tree)
    coffee: (tree) ->
        """link = require 'dt-compiler/linker'
        tree = #{render.ctbn tree}
        module.exports = (rawtemplate) -> link rawtemplate, tree
        """
    js: (tree) ->
        """var link = require('dt-compiler/linker'),
        tree = #{render.ctbn tree};
        module.exports = function (rawtemplate) {
            return link(rawtemplate, tree);
        };"""


class HTMLCompiler
    constructor: (@mode = 'default') ->
        @mode = 'jquery' # FIXME dt-parser isnt fully functional yet
        do @initialize # depending on mode
        # values
        @loaded = no
        @loading = no
        @extensions = {}
        for name, ext of HTMLCompiler.extensions
            @extensions[name] = ext
        #aliases
        @loadSync = @open

    initialize: () ->
        if @mode is 'jquery'
            # new jquery context
            jq = require('jquery').create()
            jq.fn.compile = -> jsonify this
            @parse = jq.bind(jq)
            @select = @jquerySelect
        else # is 'native'
            $ = require('dt-selector')
            @parse  = require('dt-parser')
            @select = @dtSelect
            @read   = @readStream # HACK, isnt it?


    register: (name, ext) ->
        @extensions[name] = ext

    read: (filename, callback) ->
        fs.readFile filename, (err, data) =>
            callback?.call(this, err, data?.toString())
        return null

    readStream: (filename, callback) ->
        stream = fs.createReadStream(filename)
        callback?.call(this, null, stream)
        return stream

    readSync: (filename, callback) ->
        data = fs.readFileSync(filename)?.toString()
        callback?.call(this, null, data)
        return data

    write: (path, dest, data, done) ->
        unless dest?
            return done null
        # save json dom in an own file
        rawext = extname(dest)
        ext = rawext.toLowerCase().substr(1) # without dot
        unless @extensions[ext]?
            return done new Error "file extension of #{dest} not supported."
        source = @extensions[ext](data, basename(dest, rawext))
        if path? # is root dir given?
            fullpath = pathjoin(path, dest)
        else
            fullpath = dest # hope that's a full path
        mkdirp dirname(fullpath), (err) ->
            return done err if err
            fs.writeFile(fullpath, source, done)

    dtSelect: (from, to) ->
        {from, to} = from if typeof from is 'object'
        return (el, callback) =>
            els = []
            $(el).on from, (fromel) ->
                els.push(fromel)
                $(fromel).on to, (toel) ->
                    toel.remove()
            el.on 'end', ->
                callback(els)

    jquerySelect: (from, to) -> # jquery mode only
        {from, to} = from if typeof from is 'object'
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
        @el = @parse data

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
        opts.path   ?= null # it's ok when undefined
        opts.select  = selector if selector?
        opts.error  ?= (e) -> console.error e?.stack or e
        opts.done   ?= null
        # values
        pending = no
        elem = data:[]
        elem.data = maybeDefer.call(this, opts.select, @el, @compile) if @loaded
        # when file is ready to be updated again
        done = (err) ->
            # allow to use build like load
            if opts.done?
                opts.done(err)
                # only invoke callback once (not on every fs cahnge again)
                delete opts.done
            else
                opts.error(err) if err?
            pending = no
        # compile dom to json and update opts.dest file
        reload = (err) =>
            opts.error(err) if err?
            # this updates all template linked to this design.
            # the next time a linked template is invoked it will use
            # automagicly the new data because elem doesn't change.
            elem.data = maybeDefer.call(this, opts.select, @el, @compile)
            @write(opts.path, opts.dest, elem.data, done)

        # do an auto load if not loaded so an extra load call is not needed
        @load opts.src, reload  if opts.src? and not (@loading or @loaded)
        @loading.push reload if @loading

        if opts.watch
            @watch(opts, reload)
        # done
        return elem

    watch: (opts, callback) ->
        # only watch one html file per compiler and only once
        return @watchers.push(callback) if @watching

        # initialize
        @watching = yes
        @watchers = [callback]

        # this is the filesystem listen routine
        watcher = (curr, prev) =>
            return if pending
            pending = yes
            if curr.mtime isnt prev.mtime
                # modified, wait a little before reloading
                # since modifications tend to come in waves
                setTimeout ( =>
                    try
                        do reload for reload in @watchers
                    catch err
                        opts.error(err)
                ), 11
        # no listen on fielsystem for changes
        if typeof opts.watch is 'object'
            fs.watchFile(@filename, opts.watch, watcher)
        else
            fs.watchFile(@filename, watcher)


# exports

HTMLCompiler.extensions = extensions
module.exports = HTMLCompiler

