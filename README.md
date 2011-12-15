# [Δt dynamictemplate Compiler](http://dodo.github.com/node-dt-compiler/)

This is a static HTML file to Δt template compiler. It aims to seperate the minimal required amount functionality from the actual design (given for example as mockup HTML file).

```javascript
var design = new (require('dt-compiler').Compiler);
design.build({
    src:  "index.html",
    dest: "body.js",
    select: function () {return this.select('body', '*')},
    done: function () {
        console.log("done.");
        process.exit(0);
    },
});
```

## Installation

```bash
$ npm install dt-compiler
```

## Documentation

todo

