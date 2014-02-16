{puts, inspect} = require 'util'
Server = require('./server')

server = new Server()
server.start()
