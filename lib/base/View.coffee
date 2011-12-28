types = require '../types'

function_to_string = (fun, macros) ->
  str = fun.toString()
  for own key of macros
    val = JSON.stringify macros[key]
    str.replace "//##{key}", "var #{key} = #{val};"
  str

type_by_id = (type, include_doc) ->
  map = (doc) ->
    `
    //#type
    `
    `
    //#should_include
    `
    if doc.doctype == type
      emit doc._id, if should_include then doc else null
  map = function_to_string map, type: type, should_include: include_doc
  reduce = 'count'
  return map:map, reduce:reduce

type_by_key = (type, key, include_doc) ->
  map = (doc) ->
    `
    //#type
    `
    `
    //#should_include
    `
    `
    //#key
    `
    if doc.doctype == type
      emit doc[key], if should_include then doc else null
  function_to_string map, type: type, key: key, should_include: include_doc


class View extends types.CommonClass
  constructor: (funcs) ->
    @map = funcs.map ? null
    @reduce = funcs.reduce ? null
    @post = funcs.post ? null
    @document_class = null


  _map_func: (



  
