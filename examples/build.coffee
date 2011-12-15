{ Compiler } = require '../dt-compiler'

design = new Compiler

console.log "extracting body part from index.html ..."

design.build
    src:  "index.html"
    dest: "body.js"
    select: -> @select 'body', '*'
    done:   ->
        console.log "done."
        process.exit 0
