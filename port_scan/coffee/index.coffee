##index.coffee
express = require 'express'
app = express()

app.get '/hello', (req, res) ->
  res.send 'Hello World'

app.listen 3000
console.log 'Listening on port 3000'
