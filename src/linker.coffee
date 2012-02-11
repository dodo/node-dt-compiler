{ isArray } = Array

##
# check if a string contains a substring
is_sub = (string, sub) ->
    (string?.indexOf?(sub) ? -1) isnt -1

##
# copy many objects into one
deep_merge = (objs...) ->
    objs = objs[0] if isArray(objs[0])
    res = {}
    for obj in objs
        for k, v of obj
            if typeof(v) is 'object' and not isArray(v)
                res[k] = deep_merge(res[k] or {}, v)
            else
                res[k] = v
    res

##
# copy only structure and reuse objects
# except for the dom element objects (because of the children)
copy_structure = (tree) ->
    res = []
    for el in tree ? []
        if typeof el is 'string' or typeof el is 'number'
            res.push el
            continue
        res.push
            name:     el.name
            attrs:    el.attrs
            children: copy_structure(el.children)
    return res

##
# tests a tag against the dom information from jsonify
match = (tag, el) ->
    return yes unless el? # nothing to test against
    return no if tag.name isnt el.name
    for key, value of tag.attrs
        elvalue = el.attrs[key]
        # handle some attributes in a special way
        switch key.toLowerCase()
            when 'class'
                # ignore order
                for cls in value.split(' ')
                    return no unless is_sub(elvalue, cls)
            when 'style'
                # do nothing, because we can ignore it
                # this means, that style tags can never missmatch
            else
                if value isnt elvalue
                    unless typeof value is 'string' and is_sub(elvalue, value)
                        return no
    return yes

##
# create a new tag (and children) from data structure
new_tag = (parent, el, callback) ->
    attrs = deep_merge el.attrs # copy data
    parent.tag el.name, attrs, ->
        @once 'end', ->
            callback?()
        @end()

##
# apply possible additions from the data structure on the tag
mask = (tag, el) ->
    return unless el?
    # no need to set tag.name because its the most important trigger for a match
    tag.attr el.attrs # object
    tag._elems = el.children

##
# this hooks on new instanziated templates and tries to
# complete the structure with the given html design
hook = (tpl) ->
    # register checker for creating tags
    tpl.register 'new', (parent, tag, next) ->
        elems = parent._elems
        # when this is a tag created from data structure
        return next(tag) unless elems?

        repeat = ->
            el = elems[0]

            if typeof el is 'string' or typeof el is 'number'
                elems.shift() # rm text
                parent.text?(el, append:on)
                do repeat

            else if match tag, el
                elems.shift() # rm el
                mask tag, el # apply
                delete parent._elems if elems.length is 0
                next(tag)

            else # create new tag
                # create and insert the new tag from el and delay work
                new_tag(parent, el, repeat)
        do repeat
    # register checker for closing tags
    tpl.register 'end', (tag, next) ->
        elems = tag._elems
        # when this is a tag created from data structure
        return next(tag) unless elems?

        repeat = ->
            el = elems[0]

            if typeof el is 'string' or typeof el is 'number'
                elems.shift() # rm text
                tag.text?(el, append:on)
                do repeat

            else if el?# create new tag
                # create and insert the new tag from el and delay work
                new_tag(tag, el, repeat)

            else # list is empty
                delete tag._elems
                next(tag)
        do repeat

##
# this add the data structure to the new instanziated template and hooks it
module.exports = link = (rawtemplate, tree) ->
    return (args...) ->
        tpl = rawtemplate args...
        # local copy of the data structure
        elems = copy_structure tree.data ? tree
        # nest the data tree in the root
        tpl.xml._elems = elems
        # we need to get between the events from the builder and
        # the output to change to events bahavior (inserting events before others)
        hook tpl
        # done
        return tpl

