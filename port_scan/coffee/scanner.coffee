##scanner.coffee
fs = require 'fs'
exec = require('child_process').exec
MongoClient = require('mongodb').MongoClient
http = require 'http'
qjobs = require 'qjobs'
q = new qjobs({maxConcurrency:50})

iplst = []
url = fs.readFileSync '../url', 'utf-8'

scanOne = (host,next)->
  command = 'sudo nmap -sS -sU ' + host + ' -P0 | awk \'$2=="open" {print $1}\' | sed \'s/\\/...//g\' | xargs echo -n'
  exec command, (error, stdout, stderr) ->
    MongoClient.connect 'mongodb://127.0.0.1:27017/test', (err, db) ->
      if err then throw err
      collection = db.collection 'ips'
      collection.update {ip: host}, {$set: {port: stdout.split ' '}}, {upsert:true,safe:true}, (err, docs) ->
        if err then throw err
        db.close()
        console.log host
        next()

http.get url, (res) ->
  source = ''
  res.on 'data', (data) ->
    source += data

  res.on 'end', ->
    json_data = JSON.parse source
    for ipdic in json_data.ips
      iplst.push ipdic.ip


    for ip in iplst
      q.add scanOne, ip

    q.on 'start', ->
      console.log 'Starting...'

    q.on 'end', ->
      console.log '...All jobs done'

#    q.on 'jobStart', (args) ->
#      console.log 'jobStart', args._jobId

#    q.on 'jobEnd', (args) ->
#      console.log 'jobEnd', args._jobId

    q.run()


