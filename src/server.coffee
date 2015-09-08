restify = require('restify')

createServer = ->
  server = restify.createServer()

  server.use restify.queryParser()
  server.use restify.bodyParser()
  server.use restify.gzipResponse()
  return server

module.exports =
  createServer: createServer
