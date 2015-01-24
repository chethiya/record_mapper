fs = require 'fs'
YAML = require 'yamljs'
RecordMapper = require './record_mapper'
s = fs.readFileSync './sample.yaml', 'utf8'
o = YAML.parse s

maps = o.maps
records = o.records

for m in maps
 console.log "========= Compile MAP ========"
 console.log m
 console.log '----------------------'
 map = RecordMapper.compile m
 for r, i in records
  console.log "Record #{i}: ", map r
