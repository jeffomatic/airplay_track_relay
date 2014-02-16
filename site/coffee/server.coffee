express = require 'express'
_ = require 'underscore'
{puts, inspect} = require 'util'


class Server
  constructor: (opts={}) ->
    @app = express()
    @app.set 'views', "#{__dirname}/../views"
    @app.set 'view engine', 'jade'

    @app.locals._ = _

    @app.use express.bodyParser({})
    @app.use express.cookieParser()

    @app.use (req, res, next) =>
      puts "#{req.method} #{req.url} #{inspect req.query} #{inspect req.body}"
      next()

    @app.use express.static("#{__dirname}/../public", { maxAge: 1000 * 60 });

    # This is when we actually handle the request.
    @app.use @app.router

    @app.use (err, req, res, next) =>
      next() if !err
      # error handling
      if req.accepts('html')
        res.render 'error', error: inspect(err), title: 'Error', (jadeError, html) =>
          res.send 500, html || ""
      else
        res.json 500, {error: 'Internal Server error', details: err}

    @app.get '/heartbeat', (req, res) =>
      res.send 200, {"heartbeat": true}

    @app.get '/', (req, res) =>
      res.render 'home', song: @song, (jadeError, html) =>
        puts inspect jadeError if jadeError
        res.send 200, html

    @app.get '/now-playing', (req, res) =>
      res.json 200, @song || {}

    @app.post '/now-playing', (req, res) =>
      try
        @song = _.pick(req.body, ['title', 'artist', 'album', 'ts'])
        res.send 202, "Accepted."
      catch e
        puts e
        res.send 400, "Only send me title, artist, album"

  start: ->
    port = process.env.PORT || 3333
    @server = @app.listen(port)
    console.log "Starting on port #{port}"

  stop: ->
    console.log "Actually stopping."

module.exports = Server