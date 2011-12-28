doc = require './Document.coffee'
view = require './View.coffee'

for module in [doc, view]
  for own key of module
    exports[key] = key
