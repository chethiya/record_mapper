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
window?.RecordMapper =
 map: map
