fs = require 'fs'

exports.desc = 'reads block comments and bundles into output'
exports.task = ()-> 
    content = fs.readFileSync 'src/d.coffee', 'utf8'
    blocks  = content.match /\#\#\#[^\#]+\#\#\#/g
    if blocks and blocks.length
        blocks = blocks.map (blk)-> return blk.replace(/\#{3}/g,'').replace(/^    /gm,'')
        console.log blocks.join("\n---\n")
