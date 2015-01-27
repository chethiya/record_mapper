fs = require 'fs'
YAML = require 'yamljs'
RecordMapper = require './record_mapper'
s = fs.readFileSync './sample.yaml', 'utf8'
o = YAML.parse s

maps = o.maps
records = o.records
options = null
if process.argv[2] is 'clone'
 options = {clone: on}
console.log options
for m in maps
 console.log "========= Compile MAP ========"
 console.log JSON.stringify m
 console.log '----------------------'
 map = RecordMapper.compile m, options
 for r, i in records
  console.log "Record #{i}: ", map r
