{BadValueError, MissingPropertyError} = require './exceptions'
{BigDecimal} = require 'bigdecimal'
getUUID = require('uuid-pure').newId

# So normally we don't like to do much class-based stuff in
# JavaScript's object system, but I think just for this case
# it's justified so we can get some nice inheritance-based
# type checking
class CommonObject
CommonObject::__defineGetter__ '__class__', -> @__proto__.constructor
CommonObject::__defineGetter__ '__base__', -> @__class__.__super__?.constructor ? null
# oh my gods why
z = (f) -> ((x) -> f((y) -> x(x)(y)))((x) -> f((y) -> x(x)(y)))
CommonObject::__defineGetter__ '__bases__', ->
  if @__base__
    z((f) -> (cls) -> (lst) ->
      if cls.__super__?
        f(cls.__super__.constructor)(lst.concat [cls.__super__.constructor])
      else
        lst
    )(@__base__)([@__base__])
  else
    []

class Property extends CommonObject
  @creation_counter = 0
  constructor: (options={}) ->
    @name = options.name ? "__unknown__"
    @required = options.required ? false
    @native_type = null
    @default = options.default_value ? null
    @document_class = options.document_class ? null
    Property.creation_counter++

  get_default_value: ->
    @default

  is_empty: (value) ->
    value?

  to_native: (value) ->
    value

  to_json: (value) ->
    value

  validate: (value) ->
    if @required and not value?
      throw new MissingPropertyError "Property #{@name} is missing!"
    if value and typeof value isnt @native_type
      throw new BadValueError "Property '#{@name}' type should be #{@native_type}, not #{typeof value}"
    true

  toString: ->
    klass = @__proto__.constructor.name
    "[#{klass}: '#{@name}']"


class IdProperty extends Property
  constructor: (options={}) ->
    super options
    @native_type = 'string'
    @doctype = options.doctype ? null

  get_default_value: ->
    if not @doctype
      throw new BadValueError "IdProperty can't generate an ID unless a doctype is set."
    "#{@doctype.toLowerCase()}_#{getUUID(32, 16).toLowerCase()}"


class DocTypeProperty extends Property
  constructor: (options={}) ->
    super options
    @native_type = 'string'
    @doctype = options.doctype ? null

  get_default_value: ->
    if not @doctype
      throw new BadValueError "DocTypeProperty does not have a doctype."
    @doctype

  validate: (value) ->
    if value != @get_default_value()
      throw new BadValueError "Cannot change doctype of #{@doctype} document."
    true


class AnyProperty extends Property
  to_native: (value) ->
    value

  to_json: (value) ->
    value

  validate: (value) ->
    true


class StringProperty extends Property
  constructor: (options) ->
    super options
    @native_type = "string"


class IntegerProperty extends Property
  constructor: (options) ->
    super options
    @native_type = "number"

  validate: (value) ->
    super value
    if value? and Math.floor(value) isnt value
      throw new BadValueError "Property #{name} must be an integer, but it has a fractional part."
    true

  get_default_value: ->
    @default ? 0


class FloatProperty extends Property
  constructor: (options) ->
    super options
    @native_type = "number"

  get_default_value: ->
    @default ? 0.0


class BooleanProperty extends Property
  constructor: (options) ->
    super options
    @native_type = "boolean"

  get_default_value: ->
    @default ? false


class DecimalProperty extends Property
  constructor: (options) ->
    super options
    @native_type = "object"

  validate: (value) ->
    super value
    if value? and value.__proto__ isnt BigDecimal.prototype
      throw new BadValueError "Property #{name} must be an instance of BigDecimal."
    true

  to_native: (value) ->
    new BigDecimal value

  to_json: (value) ->
    String value


class DateTimeProperty extends Property
  constructor: (options) ->
    super options
    @native_type = "object"

  validate: (value) ->
    super value
    if value? and value.__proto__ isnt Date.prototype
      throw new BadValueError "Property #{name} must be an instance of Date."
    true

  to_native: (value) ->
    date = new Date
    date.setTime value
    date

  to_json: (value) ->
    value.getTime()

  get_default_value: ->
    new Date


class DictProperty extends Property
  constructor: ->
    if arguments.length == 2
      options = arguments[0]
      @properties = arguments[1]
    else
      @properties = arguments[0]
      options = {}
    super options
    for own key of @properties
      @properties[key].name = key
    @native_type = "object"

  validate: (value) ->
    super value
    for key of @properties
      @properties[key].validate value[key] if key?
    true

  to_native: (value) ->
    keys = []
    keys.push key for own key of @properties
    keys.push key for own key of value when key not in keys and key[0] != '_'
    obj = {}
    for key in keys
      val = value[key] ? null
      if @properties[key] and val
        obj[key] = @properties[key].to_native val
      else
        obj[key] = val
    obj

  to_json: (value) ->
    keys = []
    keys.push key for own key of @properties
    keys.push key for own key of value when key not in keys and key[0] != '_'
    obj = {}
    for key in keys
      val = value[key] ? null
      if @properties[key] and val
        obj[key] = @properties[key].to_json val
      else
        obj[key] = val
    obj

  get_default_value: ->
    obj = {}
    for own key of @properties
      obj[key] = @properties[key].get_default_value()
    obj

  toString: ->
    klass = @__proto__.constructor.name
    "[#{klass}: #{@name}: { #{(@properties[key].toString() for own key of @properties).join ', '} }]"


class ArrayProperty extends Property
  constructor: ->
    if arguments.length == 2
      options = arguments[0]
      @property = arguments[1]
    else if arguments.length == 1
      @property = arguments[0]
      options = {}
    else
      @property = new AnyProperty
      options = {}
    super options
    @property.name = "[array item]"
    @native_type = 'object'

  validate: (value) ->
    super value
    for obj in value
      @property.validate obj
    true

  to_native: (value) ->
    arr = []
    for obj in value
      arr.push @property.to_native value
    arr

  to_json: (value) ->
    arr = []
    for obj in value
      arr.push @property.to_json value
    arr

  get_default_value: ->
    @default ? []


class RelationProperty extends Property
  constructor: (options={}) ->
    @relation = options.to ? null
    if @relation is null
      throw new BadValueError "Relation must have a 'to' key set."
    super options
    @native_type = 'object'

  validate: (value) ->
    proper_shortname = @relation.document_class.short_name
    id = value._id ? value
    if id.split('_')[0] != proper_shortname
      throw new BadValueError "Relation '#{@name}' must have a value of type '#{proper_shortname}'."
    true

  to_native: (value) ->
    value

  to_json: (value) ->
    value._id ? value

  get_default_value: ->
    null


class ProxyArray extends Array
  constructor: (relation, doc_id) ->
    @relation = relation
    @doc_id = doc_id
    Array.constructor.apply this

  mutate_in: (doc) ->
    doc[@relation.name] = doc_id

  mutate_out: (doc) ->
    doc[@relation.name] = null

  push: ->
    @mutate_in(doc) for doc in arguments
    do super

  pop: ->
    @mutate_out(doc) for doc in arguments
    do super

  unshift: -> 
    @mutate_in(doc) for doc in arguments
    do super

  shift: ->
    @mutate_out this[0]
    do super

  splice: ->
    idx = arguments[0]
    how_many = arguments[1]
    rest = arguments[2..]
    @mutate_out(doc) for doc in this[idx..(how_many-idx)]
    @mutate_in(doc) for doc in rest
    do super


class ProxyProperty extends Property
  constructor: (relation, options={}) ->
    super options
    @many = options.many ? false
    @native_type = 'object'

  validate: -> true

  to_native: -> undefined

  to_json: -> undefined

  get_default_value: -> undefined

module.exports =
  CommonObject: CommonObject
  Property: Property
  IdProperty: IdProperty
  DocTypeProperty: DocTypeProperty
  AnyProperty: AnyProperty
  StringProperty: StringProperty
  IntegerProperty: IntegerProperty
  FloatProperty: FloatProperty
  BooleanProperty: BooleanProperty
  DecimalProperty: DecimalProperty
  DateTimeProperty: DateTimeProperty
  DictProperty: DictProperty
  ArrayProperty: ArrayProperty
  RelationProperty: RelationProperty
  ProxyArray: ProxyArray
  ProxyProperty: ProxyProperty
