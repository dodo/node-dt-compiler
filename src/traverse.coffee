#
# /** PrivateConstants: DOM Element Type Constants
#  *  DOM element types.
#  *
#  *  ElementType.NORMAL - Normal element.
#  *  ElementType.TEXT - Text data element.
#  *  ElementType.FRAGMENT - XHTML fragment element.
#  */
DOMElementType =
    NORMAL:   1
    TEXT:     3
    CDATA:    4
    FRAGMENT: 11


##
# dom attributes to object
slim_attrs = (el) ->
    attrs = {}
    for attr in el.attributes ? []
        attrs[attr.name] = attr.value
    attrs

##
# dom element to object
slim = (el) ->
    name:     el.nodeName.toLowerCase()
    attrs:    slim_attrs(el)
    children: traverse(el.childNodes)

##
# build children list
traverse = (elems) ->
    return [] unless elems?
    res = []
    for el in elems
        if el.nodeType is DOMElementType.NORMAL
            res.push slim el
        else if el.nodeType is DOMElementType.TEXT
            if el.nodeValue.trim().length
                res.push el.nodeValue
        else continue
    return res

# exports

module.exports = { slim_attrs, slim, traverse, jsonify:traverse }

