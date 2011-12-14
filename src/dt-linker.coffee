module.exports = require './linker'

# exports

( ->
    if @dynamictemplate?
        @dynamictemplate.link = link
    else
        @dynamictemplate = module.exports
).call window if process.title is 'browser'

