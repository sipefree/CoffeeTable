types = require '../types'
exceptions = require '../exceptions'

class Document extends types.CommonObject
  _id: new types.IdProperty
  doctype: new types.DocTypeProperty

  constructor: (dict) ->
    name = @__proto__.constructor.name.toLowerCase()
    properties = {}
    @_id.doctype = name
    @doctype.doctype = name

    # replace properties
    for key of this
      if types.Property in (this[key].__bases__ ? [])
        properties[key] = this[key]
        properties[key].document_class = @__class__
        if dict and dict[key]?
          this[key] = properties[key].to_native dict[key]
        else
          this[key] = properties[key].get_default_value()
        if this[key] == undefined
          delete this[key]

    # add extra keys
    for own key of dict
      if not this[key]
        this[key] = dict[key]

    @_properties = new types.DictProperty properties

  to_json: ->
    @_properties.to_json this

  save: ->
    console.log "Saving document #{@_id}"

  remove: ->
    console.log "Removing document #{@_id}"


Empty = (->).__proto__
class DocumentClass extends Empty

DocumentClass::__defineGetter__ 'short_name', ->
  @.name.toLowerCase()

registerClass = (cla) ->
  cla.__proto__ = DocumentClass.prototype


class Person extends Document
  name: new types.StringProperty
  age: new types.IntegerProperty
  address: new types.DictProperty {
    street: new types.StringProperty
    town: new types.StringProperty
    country: new types.StringProperty
  }
  created: new types.DateTimeProperty

  address_string: ->
    "#{@address.street}\n#{@address.town}\n#{@address.country}"


registerClass Person

personDict =
  _id: "person_56df794e3f04724d0fb43724c29f66e9"
  doctype: "person"
  name: "Jon Doe"
  age: 22
  address:
    street: "123 Fake Street"
    town: "Faketown"
    country: "Ireland"
  created: 1324768764635

module.exports =
  Document: Document
  Person: Person
  pd: personDict
  p: new Person personDict

