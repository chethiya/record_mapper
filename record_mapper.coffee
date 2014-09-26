getField = (record, field) ->
 if field instanceof Array
  v = record
  v = v?[k] for k in field
  return v
 else
  return record[field]

createField = (str) ->
 arr = str.split '.'
 if arr.length is 1
  return str
 else
  return arr

createRegex = (r) ->
 if r instanceof RegExp
  return r
 else if r instanceof Array
  return new RegExp r[0], r[1]
 else if 'string' is typeof r
  return new RegExp r
 else
  throw "Invalid Regexp #{r}"

oper =
 map: (context) ->
  f = (record) ->
   getField record, @field
  return f.bind context
 date: (context, key) ->
  f = (record) ->
   v = getField record, @field
   if v instanceof Date
    return v
   else if typeof v is 'string'
    if @split?
     arr = v.split @split.regex
     yy = parseInt arr[@split.index[0]]
     mm = parseInt arr[@split.index[1]] - 1
     dd = parseInt arr[@split.index[2]]
     return new Date yy, mm, dd
    else
     return new Date v
   else
    return null

  if context.split?
   if context.split.regex?
    try
     context.split.regex = createRegex context.split.regex
    catch
     throw "Invalid regex given for map #{key}"
   else
    context.split.regex = /[\.\-\/\\]/
   if not context.split.index?
    throw "Date split index is not given for map #{key}"
   if not context.split.index instanceof Array or context.split.index.length isnt 3
    throw "Date split index is not an array of length 3 for map #{key}"
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
   throw "Invalid regex given for map #{key}"
  if not context.newValue? or 'string' isnt typeof context.newValue
   throw "Invalid newValue given for map #{key}"
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
   if not context.selects instanceof Array
    throw "selects need to be an array in map #{key}"
   for s, i in context.selects
    if not s.select? or not s.select instanceof Array
     throw "Invalid select (index - #{i}) in map #{key}"
    for r, j in s.select
     try
      s.select[j] = createRegex r
     catch
      throw "Invalid regex #{r} in map #{key}"

  return f.bind context

compile = (config) ->
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

 for k, v of config
  if typeof v is 'string'
   maps[k] = oper.map field: createField v
  else
   if not v.field? or 'string' isnt typeof v.field
    throw "No/invalid field given for map #{k}"
   if not v.type? or 'string' isnt typeof v.type
    throw "No/invalid mapping type given for map #{k}"

   context = {}
   context[key] = val for key, val of v

   context.field = createField context.field
   if context.type is 'map'
    maps[k] = oper.map context, k
   else if context.type is 'date'
    maps[k] = oper.date context, k
   else if context.type is 'replace'
    maps[k] = oper.replace context, k
   else if context.type is 'switch'
    maps[k] = oper.switch context, k
   else
    throw "Unsupported mapping type #{context.type} in map #{k}"

 console.log 'created maping: ', maps
 mapFunc = (record) ->
  if len is -1
   res = {}
  else
   res = new Array len
  for k, f of @maps
   res[k] = f record
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
