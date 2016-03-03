TYPE_MAP = 0
TYPE_ARRAY = 1
TYPE_LITERAL = 2

twoDigit = (d) ->
 if d < 10
  "0#{d}"
 else
  "#{d}"

getField = (record, field) ->
 if field instanceof Array
  v = record
  v = v?[k] for k in field
  return v
 else
  return record[field]

setField = (record, field, val, fieldMap) ->
 if record?
  if field instanceof Array
   for i in [0...field.length-1]
    fieldMap = fieldMap.keys[field[i]]
    if not record[field[i]]?
     if fieldMap.type is TYPE_MAP
      record[field[i]] = {}
     else if fieldMap.type is TYPE_ARRAY
      record[field[i]] = new Array fieldMap.arrayLength
    record = record[field[i]]
   record[field[field.length-1]] = val
  else
   record[field] = val

createField = (str) ->
 if 'string' is typeof str
  arr = str.split '.'
  for v, i in arr
   val = parseInt v
   if not isNaN val
    arr[i] = val
  return arr
 else
  return str

createFieldMap = (keys) ->
 fields = []
 for k in keys
  fields.push createField k
 fields.sort (a, b) ->
  l = Math.min a.length, b.length
  for i in [0...l]
   if a[i] isnt b[i]
    if (typeof a) is (typeof b)
     return a < b
    else if 'number' is typeof a
     return 1
    else
     return -1
  return 0

 res =
  type: TYPE_ARRAY
  arrayLength: 0
  keys: {}
 last = []
 for f in fields
  m = res
  min = Math.min last.length, f.length
  start = 0
  found = off
  for i in [0...min]
   if last[i] isnt f[i]
    start = i
    found = on
    break
   m = m.keys[f[i]]
  last = f
  if found is off
   start = min
   if f.length > start and m.type is TYPE_LITERAL
    m.type = TYPE_ARRAY
    m.arrayLength = 0

  for i in [start...f.length]
   if m.type is TYPE_ARRAY and ('number' is typeof f[i])
    m.arrayLength++
   else
    m.type = TYPE_MAP
   nextType = TYPE_ARRAY
   nextType = TYPE_LITERAL if i is f.length-1
   m.keys[f[i]] =
    type: nextType
    arrayLength: 0
    keys: {}
   m = m.keys[f[i]]
 return res

createRegex = (r) ->
 if r instanceof RegExp
  return r
 else if r instanceof Array
  return new RegExp r[0], r[1]
 else if 'string' is typeof r
  return new RegExp r
 else
  throw new Error "Invalid Regexp #{r}"

oper =
 map: (context) ->
  f = (record) ->
   getField record, @field
  return f.bind context

 const: (context) ->
  f = (record) -> @value
  return f.bind context

 date: (context, key) ->
  f = (record) ->
   v = getField record, @field
   res = null
   if v instanceof Date
    res = v
   else if typeof v is 'string'
    if @split?
     arr = null
     if @split.regex?
      arr = v.split @split.regex
     else if @split.lengths?
      arr = []
      start = 0
      for l in @split.lengths
       arr.push v.substr start, l
       start += l
     yy = parseInt arr[@split.index[0]]
     mm = parseInt arr[@split.index[1]]
     dd = parseInt arr[@split.index[2]]
     # Time is 00:00 in UTC
     res = new Date Date.UTC yy, mm, dd
    else
     res = new Date v
   else if typeof v is 'number'
    res = new Date v
   else
    res = null

   if res? and @return?.type? and @return.type is 'string'
    return "#{res.getYear()+1900}#{@return.separator}#{twoDigit res.getMonth()+1}" +
    "#{@return.separator}#{twoDigit res.getDate()}"
   else
    return res

  if context.split?
   if context.split.regex?
    try
     context.split.regex = createRegex context.split.regex
    catch
     throw new Error "Invalid regex given for map #{key}"
   else if not context.split.lengths?
    context.split.regex = /[\.\-\/\\]/
   if not context.split.index?
    throw new Error "Date split index is not given for map #{key}"
   if not (context.split.index instanceof Array) or context.split.index.length isnt 3
    throw new Error "Date split index is not an array of length 3 for map #{key}"
  return f.bind context

 replace: (context, key) ->
  f = (record) ->
   v = getField record, @field
   if 'object' isnt typeof v
    v = "#{v}"
    return v.replace @regex, @newValue
   else
    return v
  try
   context.regex = createRegex context.regex
  catch
   throw new Error "Invalid regex given for map #{key}"
  if not context.newValue? or 'string' isnt typeof context.newValue
   throw new Error "Invalid newValue given for map #{key}"
  return f.bind context

 switch: (context, key) ->
  f = (record) ->
   v = getField record, @field
   for s in @selects
    for regex in s.select
     if regex.test v
      return s.value
   return @default

  if context.selects?
   if not (context.selects instanceof Array)
    throw new Error "selects need to be an array in map #{key}"
   for s, i in context.selects
    if not s.select? or not (s.select instanceof Array)
     throw new Error "Invalid select (index - #{i}) in map #{key}"
    for r, j in s.select
     try
      s.select[j] = createRegex r
     catch
      throw new Error "Invalid regex #{r} in map #{key}"

  return f.bind context

 number: (context, key) ->
  f = (record) ->
   v = getField record, @field
   if v?
    if typeof v is 'string' and @removeRegex?
     v = v.replace @removeRegex, ''
    v = parseFloat v
    if not isNaN v
     return v
   return null

  if context.removeRegex?
   try
    context.removeRegex = createRegex context.removeRegex
   catch
    throw new Error "Invalid regex given for map #{key}"

  return f.bind context

 sum: (context, key) ->
  f = (record) ->
   res = 0
   for f in @fields
    v = getField record, f
    if not isNaN v
     res += v
   return res
  context.fields ?= []
  return f.bind context

 concat: (context, key) ->
  f = (record) ->
   res = ''
   for f, i in @fields
    if i > 0
     res += @separator
    res += getField record, f
   return res
  context.separator ?= '|'
  context.fields ?= []
  return f.bind context


compile = (config, options) ->
 len = 0
 for k of config
  if (typeof k is 'number' and k is parseInt k) or (typeof k is 'string' and (parseInt k) is (parseFloat k) and not isNaN parseInt k)
   len = Math.max len, 1 + parseInt k
  else
   len = -1
   break
 if len is -1
  maps = {}
 else
  maps = new Array len

 keys = (k for k of config)
 fieldMap = createFieldMap keys

 for k, v of config
  maps[k] =
   oper: null
   keyField: createField k
  if typeof v is 'string'
   maps[k].oper = oper.map field: createField v
  else
   if not v.type? or 'string' isnt typeof v.type
    throw new Error "The field #{k} has no/invalid mapping type"
   if v.type is 'const' and not v.value?
    throw new Error "The field #{k} has no constant value given"
   else if v.type is 'sum' or v.type is 'concat'
    if not v.fields?
     throw new Error "Fields are not mapped in #{k}"
   else if v.type isnt 'const'
    if not v.field?
     throw new Error "The field #{k} has no mapping field"

   context = {}
   context[key] = val for key, val of v

   if context.field?
    context.field = createField context.field
   else if context.fields?
    for f, i in context.fields
     context.fields[i] = createField f

   if context.type is 'map'
    maps[k].oper = oper.map context, k
   if context.type is 'const'
    maps[k].oper = oper.const context, k
   else if context.type is 'date'
    maps[k].oper = oper.date context, k
   else if context.type is 'replace'
    maps[k].oper = oper.replace context, k
   else if context.type is 'switch'
    maps[k].oper = oper.switch context, k
   else if context.type is 'number'
    maps[k].oper = oper.number context, k
   else if context.type is 'sum'
    maps[k].oper = oper.sum context, k
   else if context.type is 'concat'
    maps[k].oper = oper.concat context, k
   else
    throw new Error "The field #{k} has Unsupported mapping type #{context.type}"

 options ?= {}

 mapFunc = (record) ->
  if options.clone is on
   if record instanceof Array
    res = []
    for item in record
     res.push item
   else
    res = {}
    for k, v of record
     res[k] = v
  else if options.sameObject is on
   res = record
  else
   if fieldMap.type is TYPE_MAP
    res = {}
   else if fieldMap.type is TYPE_ARRAY
    res = new Array fieldMap.arrayLength
  for k, map of @maps
   setField res, map.keyField, (map.oper record), fieldMap
  return res

 return mapFunc.bind maps: maps

#direct map.
map = (conf, record) ->
 r = null
 len = 0
 for k of conf
  if (typeof k is 'number' and k is parseInt k) or (typeof k is 'string' and (parseInt k) is (parseFloat k) and not isNaN parseInt k)
   len = Math.max len, 1 + parseInt k
  else
   len = -1
   break

 if len > -1
  r = new Array(len)
 else
  r = {}
  r[k] = undefined for k of conf
 return r unless record?

 for k, v of conf
  k = parseInt k if len > -1
  if typeof v is 'string'
   r[k] = record[v] if record[v]?
  else if typeof v is 'object' and v.type?
   if v.type is 'date'
    d = record[v.field]
    d = new Date d if typeof d is 'string'
    r[k] = d if d instanceof Date
   else if v.type is 'string'
    r[k] = "#{record[v.field]}" if record[v.field]?
   else if v.type is 'int'
    r[k] = parseInt record[v.field] if record[v.field]?
 return r

exports?.map = map
exports?.compile = compile
window?.RecordMapper =
 map: map
 compile: compile
