##scanner.coffee
fs = require 'fs'
exec = require('child_process').exec
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
    if stdout != '' or stdout != ' '
      db.ips.update {ip: host}, {$set: {port: Number(i) for i in stdout.split(' '), update: Date()}}, {upsert:true}, (err, docs) ->
        if err then throw err
        console.log host
    else
      db.ips.update {ip: host}, {$set: {port: [], update: Date()}}, {upsert:true}, (err, docs) ->
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

    #remove unused ip
    db.ips.find({},{'_id': false, 'port': false}).forEach (err, docs) ->
      if err then throw err
      if docs != null
        if docs.ip not in iplst
          db.ips.remove {'ip': docs.ip}

    #add jobs to q
    for ip in iplst
      q.add scanOne, ip

    q.on 'start', ->
      console.log 'Starting...'

    q.on 'end', ->
      console.log '...All jobs done'
      db.close()

    q.run()


