class CoffeeTableException
  constructor: (str) ->
    @error = str

  toString: ->
    return "#{@__proto__.constructor.name}: #{@error}"

class exports.BadValueError extends CoffeeTableException
class exports.MissingPropertyError extends CoffeeTableException
