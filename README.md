# [Δt dynamictemplate Compiler](http://dodo.github.com/node-dt-compiler/)

This is a static HTML file to [Δt](http://dodo.github.com/node-dynamictemplate/) template compiler. It aims to seperate the minimal required amount of functionality from the actual design (given for example as mockup HTML file).


## Installation

```bash
$ npm install dt-compiler
```


## Usage

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


## Documentation

Keep your projects design automagically up-to-date while your web designer iterates over the mockup HTML files.

This module generates masks out of mockup HTML files which can later applied on Templates to get the same result as in the mockup.

Don't write your template completely from scratch, just use the mockup file of your designer and write only those tags, that you want to enchant with functionality.

Template tags behave like selectors, if a new tag doesn't match with the mask, the not fitting mask tag gets created. (see `link` for more).

The goal of this module is to provide an automated seperation of functionality and design.

__Note__

This module changes the behavior of [asyncxml](http://dodo.github.com/node-asyncxml). All tag creation statements behave like selectors on the mask.
So when you write a tag statement, it no longer just simply creates a new tag, it tries to match the new tag with what is given in the mask on the same level in the same parent tag. If you for example try to create a new tag that doesn't match with the mask, it creates all mask parts first, before creating your new tag. that means if you make a mistake or the designer change the name of a class, that you try to match, you will get not a broken template but the html would contain double content.

example:

```html
<div class="parent">
    <div class="logo"></div>
    <div class="controls"></div>
    <div class="first entry"></div>
    <div class="second entry"></div>
</div>
```

```javascript
new Template({schema:5}, function () {
    this.$div({class:'parent'}, function () {
        // we dont the logo, so skip it
        this.$div({class:'controls'}, function () { … });
        this.$div({class:'fist entry'}, function () { … }); // here is a typo!
        this.$div({class:'second entry'}, function () { … }); // thats just fine
    });
});
```

result:

```html
<div class="parent"><!-- matched -->
    <div class="logo"></div><!-- from mask -->
    <div class="controls"></div><!-- matched -->
    <div class="first entry"></div><!-- from mask -->
    <div class="second entry"></div><!-- from mask -->
    <div class="fist entry"></div><!-- created -->
    <div class="second entry"></div><!-- created -->
</div>
```

If you or your designer doesn't like to write pure HTML mockup files, use another template engine, which is better for generating static HTML than [dynamic template](http://dodo.github.com/node-dynamictemplate).
Like [HAML](http://haml-lang.org) or whatever floats your boat.

## api

### Compiler()

#### compiler.load(filename, callback)

```javascript
compiler.loadSync(path.join(__dirname, "index.html"))
```
A Compiler can load and parse exactly one HTML mockup file.

Use this method if you want to build more than one mask from the mockup.

If you only have one mask to compile then you can skip to call this method and specify the HTML file as `opts.src` in the `Compiler::build` method.

#### compiler.build([opts], [selector])

```javascript
compiler.build({
    src:  "index.html",
    dest: "body.js",
    select: function () {return this.select('body', '*')},
    done: function () {console.log("body mask successful compiled.");},
});
```
* `opts.path` Root directory of the desitnation file. Use this if you use an extension handler that requires a clean filename (like in the given example to `Compiler::register`).
* `opts.dest` Destination file to write to. The file extension defines the output format. (see `Compiler::register` for more).
* `opts.src` HTML mockup source filename. (see `Compiler::load` for more).
* `opts.watch` If true the compiler will recompile the mask. (default false).
* `opts.select` This function get called every time the compiler recompiles a the mask. (defaults to second argument `selector`). (see `Compiler::select` for more).
* `opts.error` For debugging purose. (defaults to console.error)
* `opts.done` Callback gets called everytime when the mask was successful compiled and written to file system.

Build a mask from a HTML mockup.

You can build as many masks as you need with one Compiler instance.

A mask a specific range from the HTML XML tree specified by the `selector` function.


#### compiler.select(from, [to])

```html
<div class="container">
    <ul class="list">
        <div class="controls">
            <a href="#">sort</a>
        </div>
        <li class="entry">
            blub blub
        </li>
        <li class="entry">
            foo bar
        </li>
    </ul>
</div>
```
```javascript
compiler.build({
    path:path.join(__dirname, "masks"),
    dest: "list.js",
    select: function () {
        var el = this.select('.list', 'li'); // select ul tag and all children, but remove all li entries
        el.find('.controls > a:first').attr('href', '/sort'); // set static url
        return el;
    },
});

```

This method expects [CSS selectors](http://sizzlejs.com/) as arguments.

* The `from` argument selects all matching HTML nodes which you want to include into your mask.
* The `to` argument selects all matching HTML nodes selected by the `from` selector and excludes them from the mask.

It returns a jQuery Object.

__info__ Do as many jQuery transformations (like removing lorum ipsum or removing unnecessary tags) in the selector (`opts.select` of `Compiler::build`) as possible to avoid them in the template.

The given example selects only the ul tag and the div.controls with children but removes all li tags.

If you choosed '.js' as file extension for the masks destination file, the mask can be just simply applied like this:

```javascript
var template = {};
template.list = require('./masks/list')(function (view) {
    return new Template({schema:5, pretty:true}, function () {
        this.$ul(function () { // ← this matches with the first entry in the mask, which is the ul take.
            view.on('entry', this.add); // append new entries to the list
        });
    });
});
```
Which results in:

```html
<ul class="list">
    <div class="controls">
        <a href="/sort">
        sort
        </a>
    </div>
</ul>
```

#### compiler.register(name, extension)

```javascript
compiler.register('.js', function (tree, name) { // overwrite existing '.js' extension handler
        var data = JSON.stringify(tree);
        return "window.masks = window.masks || {};\n" +
               "window.masks['"+name+"']=function(rawtemplate) {" +
               "return window.dynamictemplate.link(rawtemplate, "+data+")};";
});
```

Register a new extension handler or overwrite an existing one.

The file extension specifies how the output of the compiler should look like.

E.g. if you choose the given example your able to add your masks with script tags:

```html
<script src="/masks/list.js"></script>
```
And get them via:

```javascript
window.masks['list'](function (view) {
    return new Template({schema:5, pretty:true}, function () {
        this.$ul();
    });
});
```

### link(rawtemplate, maskdata)

```javascript
var data = { … }; // generated by the compiler
window.masks = window.masks || {};
window.masks['<name>'] = function (rawtemplate) {
    return window.dynamictemplate.link(rawtemplate, data);
});
```

The Compiler produces only simple data representations of the dom model of the mask. These need to be reapplied to a fresh [Template instance](http://dodo.github.com/node-dynamictemplate/doc.html).

This method should be only of concern if you want to write your own extension handler.

The masks have a special behavior when they get applied. If a new Tag gets created in the template the linker tries to match this tag with the next entry in the mask. If it is a match, the tag can be fully created. If it's not matching, the new tag gets delayed and the entry from the mask will be created. This check contiues until a match was found (in that case the mask entry gets remove from the mask).


```html
<!-- assuming this is the dom representation of the mask -->
<div>
    <a href="/home">home</a>
    <span>dummy content</span>
</div>
```

```javascript
return new Template({schema:5}, function () {
    this.$div(function () { // first entry in the mask is a div, so this is a match
        // not match with the next entry in the mask, which is an a tag
        this.$span("real content"); // this is delayed until the a tag is created
        // after that it is match with the next entry of the mask, which is a span tag
    });
});
````

The result of that template would be that the output looks the same like the mask, but the span tag has a different content.
