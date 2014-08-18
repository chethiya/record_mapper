fs = require 'fs'
YAML = require 'yamljs'
RecordMapper = require './record_mapper'
s = fs.readFileSync './sample.yaml', 'utf8'
o = YAML.parse s

maps = o.maps
records = o.records

for m in maps
 console.log "========= MAP ========"
 console.log m
 console.log '----------------------'
 for r, i in records
  console.log "Record #{i}: ", RecordMapper.map m, r
