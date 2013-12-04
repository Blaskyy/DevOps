##scanner.coffee
fs = require 'fs'
exec = require('child_process').exec
#MongoClient = require('mongodb').MongoClient
mongojs = require 'mongojs'
http = require 'http'
qjobs = require 'qjobs'
db = mongojs('test', ['ips'])
q = new qjobs({maxConcurrency:30})

iplst = []
url = fs.readFileSync '../url', 'utf-8'

scanOne = (host,next)->
  command = 'sudo nmap -sS -sU ' + host + ' -P0 | awk \'$2=="open" {print $1}\' | sed \'s/\\/...//g\' | xargs echo -n'
  exec command, (error, stdout, stderr) ->
    #MongoClient.connect 'mongodb://127.0.0.1:27017/test', (err, db) ->
      #if err then throw err
      #collection = db.collection 'ips'
    db.ips.update {ip: host}, {$set: {port: stdout.split ' '}}, {upsert:true}, (err, docs) ->
      if err then throw err
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

    db.ips.find({},{'_id': false, 'port': false}).forEach (err, docs) ->
      if err then throw err
      if docs != null
        if docs.ip not in iplst
          db.ips.remove {ip: docs.ip}

    for ip in iplst
      q.add scanOne, ip

    q.on 'start', ->
      console.log 'Starting...'

    q.on 'end', ->
      console.log '...All jobs done'
      db.close()

#    q.on 'jobStart', (args) ->
#      console.log 'jobStart', args._jobId

#    q.on 'jobEnd', (args) ->
#      console.log 'jobEnd', args._jobId

    q.run()


