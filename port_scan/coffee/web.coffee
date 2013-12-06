##web.coffee
mongojs = require 'mongojs'
express = require 'express'
EventProxy = require 'eventproxy'
db = mongojs 'test', ['ips']
app = express()
app.use express.bodyParser()

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
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  body = {}
  body['data']={}
  db.ips.find {},{'_id': false}, (err, docs) ->
    if err then throw err
    if docs
      ep = new EventProxy()
      ep.after 'one_data', docs.length, ->
        res.end(JSON.stringify body, null, 2)
      for i in docs
        do (i) ->
          body['data'][i.ip] = {}
          body['data'][i.ip]['port'] = i.port
          body['data'][i.ip]['update'] = i.update
          ep.emit 'one_data'

app.get '/fip/:from-:to', (req, res) ->
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  body = {}
  body['data'] = {}
  db.ips.find {'ip': {$in: num2ip(i) for i in [ip2num(req.params.from)..ip2num(req.params.to) ]}},{'_id': false, 'update':false}, (err, docs) ->
    if err then throw err
    if docs
      ep = new EventProxy()
      ep.after 'one_ip', docs.length, ->
        res.end(JSON.stringify body, null, 2)
      for i in docs
        do (i) ->
          body['data'][i.ip] = {}
          body['data'][i.ip]['port'] = i.port
          ep.emit 'one_ip'

app.get '/fport/:from-:to', (req, res) ->
  ep = new EventProxy()
  ep.after 'one_port', [Number(req.params.from)..Number(req.params.to)].length, ->
    res.end(JSON.stringify body, null, 2)
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  body = {}
  body['data'] = {}
  for i in [Number(req.params.from)..Number(req.params.to)]
    do (i) ->
      db.ips.find {'port': {$all: [i]}}, {'_id': false, 'port': false, 'update': false}, (err, docs) ->
        if err then throw err
        if docs.length != 0
          body['data'][i] = (j['ip'] for j in docs)
          ep.emit 'one_port'
        else
          ep.emit 'one_port'

app.get '/alarm/:port_tmp', (req, res) ->
  ports = (Number(i) for i in req.params.port_tmp.split '|')
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  body = {}
  body['data'] = {}
  db.ips.find {}, {'_id': false, 'update': false}, (err,docs) ->
    if err then throw err
    if docs
      ep = new EventProxy()
      ep.after 'one_data', docs.length, ->
        res.end(JSON.stringify body, null, 2)
      for i in docs
        do (i) ->
          body['data'][i.ip]={}
          body['data'][i.ip]['port'] = (j for j in i.port when j not in ports)
          if body['data'][i.ip]['port'].length == 0
            body['data'][i.ip]['status'] = true
            ep.emit 'one_data'
          else
            body['data'][i.ip]['status'] = false
            ep.emit 'one_data'

app.get '/wlst/:from-:to\::port_tmp', (req, res) ->
  ports = (Number(i) for i in req.params.port_tmp.split '|')
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  body = {}
  body['data'] = {}
  db.ips.find {'ip': {$in : num2ip(i) for i in [ip2num(req.params.from)..ip2num(req.params.to)]}}, {'_id': false, 'update': false}, (err,docs) ->
    if err then throw err
    if docs
      ep = new EventProxy()
      ep.after 'one_data', docs.length, ->
        res.end(JSON.stringify body, null, 2)
      for i in docs
        do (i) ->
          body['data'][i.ip]={}
          body['data'][i.ip]['port'] = (j for j in i.port when j not in ports)
          ep.emit 'one_data'

app.get '/', (req, res) ->
  res.setHeader('Content-Type', 'text/html; charset=utf-8')
  body = '''<center>
  <form action="/" method="post">
  IP  <input type="text" name="ip_tmp" />
  port <input type="text" name="port_tmp" />
  <input type="submit" port="Filter" />
  </form>
  Usage:
  <p>只填写端口则返回开放该端口的IP列表,可填写格式为单个端口或端口段,如"22-53"</p>
  <p>只填写IP则返回该IP的端口信息,可填写格式为单个IP或IP段,如"192.168.1.1-192.168.1.255"</p>
  <p>若既填写IP也填写端口,则返回该IP段除了填写的端口之外开放的端口信息,可填写IP格式,单个IP或IP段,可填写端口格式为单个端口或用竖线"|"隔开的多个端口,如"22|80"</p>
  API:
  <p>Filter ip: http://localhost/fip/ipfrom-ipto</p>
  <p>Filter port: http://localhost/fport/portfrom-portto</p>
  <p>Alarm data: http://localhost/alarm/22|53|80|500 (替换为要排除的端口)</p>
  <p>White list: http://localhost/wlst/ipfrom-ipto:22|53|80|500 (替换为要排除的端口)</p>
  </center>'''
  res.end body

app.post '/', (req, res) ->
  ip_tmp = req.body.ip_tmp if req.body.ip_tmp?
  port_tmp = req.body.port_tmp if req.body.port_tmp?
  if ip_tmp != '' and port_tmp == ''
    ips = ip_tmp.split '-'
    if ips.length == 1
      res.redirect "/fip/#{ips[0]}-#{ips[0]}"
    else
      res.redirect "/fip/#{ips[0]}-#{ips[1]}"
  else if ip_tmp == '' and port_tmp != ''
    ports = port_tmp.split '-'
    if ports.length == 1
      res.redirect "/fport/#{ports[0]}-#{ports[0]}"
    else
      res.redirect "/fport/#{ports[0]}-#{ports[1]}"
  else
    ips = ip_tmp.split '-'
    res.redirect "/wlst/#{ips[0]}-#{ips[1]}:#{port_tmp}"

app.listen(3000)

