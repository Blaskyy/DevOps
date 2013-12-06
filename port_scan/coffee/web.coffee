##web.coffee
mongojs = require 'mongojs'
express = require 'express'
EventProxy = require 'eventproxy'
db = mongojs 'test', ['ips']
app = express()

ip2num = (ipstr) ->
  ip = 0
  ipdot = ipstr.split('.').reverse()
  ipis = ipdot.map (v, i) ->
          return v * Math.pow(256, i)
  ipis.forEach (v,i) -> return ip+=v
  return ip

num2ip = (ipnum) ->
  ipis = [0,0,0,0]
  ipdots = ipis.map (v, i) ->
    n = Math.pow(256, 3-i)
    ipdot = parseInt(ipnum / n)
    ipnum = ipnum % n
    return ipdot
  return ipdots.join('.')

app.get '/result', (req, res) ->
  body = {}
  body['ips']=[]
  db.ips.find({},{'_id': false}).forEach (err, doc) ->
    if err then throw err
    if doc
      body['ips'].push doc
    else
      res.end(JSON.stringify body, null, 2)
  res.setHeader('Content-Type', 'application/json')

app.get '/fip/:from-:to', (req, res) ->
  ep = new EventProxy()
  ep.after 'one_ip', [ip2num(req.params.from)..ip2num(req.params.to)].length, ->
    res.end(JSON.stringify body, null, 2)
  res.setHeader('Content-Type', 'application/json')
  body = {}
  body['data'] = {}
  db.ips.find({'ip': {$in: num2ip(i) for i in [ip2num(req.params.from)..ip2num(req.params.to) ]}},{'_id': false}).forEach (err, doc) ->
    if err then throw err
    if doc
      body['data'][doc.ip] = doc.port
    ep.emit 'one_ip'

app.get '/fport/:from-:to', (req, res) ->
  ep = new EventProxy()
  ep.after 'one_port', [Number(req.params.from)..Number(req.params.to)].length, ->
    res.end(JSON.stringify body, null, 2)
  res.setHeader('Content-Type', 'application/json')
  body = {}
  body['data'] = {}
  for i in [Number(req.params.from)..Number(req.params.to)]
    do (i) ->
      db.ips.find {'port': {$all: [i]}}, {'_id': false, 'port': false, 'update': false}, (err, docs) ->
        if err then throw err
        if docs.length != 0
          body['data'][i] = (j['ip'] for j in docs)
        ep.emit 'one_port'














app.listen(3000)

