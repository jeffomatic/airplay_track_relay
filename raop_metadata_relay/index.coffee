#!/usr/bin/env coffee
_ = require('underscore')
deep = require('deep')
dgram = require('dgram')
events = require('events')
request = require('request')

{puts, inspect} = require('util')
raopSocket = dgram.createSocket("udp4")

config =
  debug: true
  debounceTime: 5000
  metadataPort: 12345
  playlisttt:
    baseUrl: 'http://localh.ifttt.com:3000'
    #baseUrl: 'http://playlisttt.ifttt.com'
    accessToken: process.env.PLAYLISTTT_ACCESS_TOKEN

splitBuffer = (buffer, offset) ->
  [buffer.slice(0, offset), buffer.slice(offset, buffer.length)]

debugLog = (args...) ->
  return unless config.debug
  puts args...

debounce = (targetFunc, time) ->
  prevTime = 0
  prevArgs = null

  (args...) ->
    now = Date.now()
    return if (now - prevTime) < time && deep.equals(args, prevArgs)
    prevTime = now
    prevArgs = args
    targetFunc args...

messageCount = 0
messageEmitter = new events.EventEmitter
announceMessage = debounce (message) ->
  # Debug ouptut
  messageCount += 1
  debugLog "Message count: #{messageCount}"

  # Add message timestamp
  message = _.extend(
    {},
    message,
    ts: (Date.now() / 1000) | 0
  )

  # Send to listeners
  messageEmitter.emit 'message', message
, config.debounceTime

raopSocket.on "message", (msg, rinfo) ->
  debugLog "Message Received: #{inspect rinfo}\n\n #{msg.toString()}"

  containers = [
    'mcon'
    'mlcl'
    'mlit'
    'mbcl'
    'mdcl'
    'msrv'
    'mlag'
    'mupd'
    'mudl'
    'mccr'
  ]

  tagTransform =
    asar: 'artist'
    asal: 'album'
    minm: 'title'
    astm: 'lengthms'

  valueTransform =
    astm: (data) -> data.readInt32BE(0)

  rawTags = {}
  transformedTags = {}

  debugLog "<dmapcontent>"

  while msg.length > 0
    # Tag
    [rawTag, msg] = splitBuffer(msg, 4)

    # Tag data size
    [rawTagDataSize, msg] = splitBuffer(msg, 4)
    tagDataSize = rawTagDataSize.readInt32BE(0)
    debugLog "\t<tag name=#{rawTag}, size=#{tagDataSize}>"

    if containers.indexOf(rawTag.toString()) >= 0
      debugLog "\t\t[container]"
    else
      # Tag data
      [rawData, msg] = splitBuffer(msg, tagDataSize)
      debugLog "\t\t<data>"
      debugLog "\t\t" + rawData.toString()
      debugLog "\t\t</data>"

      # Collect tags
      rawTags[rawTag.toString()] = rawData.toString()

      # Transform tag titles if necessary
      tag = rawTag.toString()
      if transformed = tagTransform[tag]
        if xform = valueTransform[tag]
          transformedTags[transformed] = xform(rawData)
        else
          transformedTags[transformed] = rawData.toString()

    debugLog "\t</tag>"

  debugLog "</dmapcontent>"

  # New song plays should have a title and a non-zero song time
  if transformedTags.title?.length > 0 \
  && transformedTags.lengthms? \
  && transformedTags.lengthms > 0
    announceMessage transformedTags

raopSocket.on "listening", ->
  {address, port} = @address()
  debugLog "Metadata socket started on #{address}:#{port}"

raopSocket.on "close", ->
  {address, port} = @address()
  debugLog "Metadata socket closed on #{address}:#{port}"
  exit()

raopSocket.on "error", (exception) ->
  debugLog "Metadata socket error"
  debugLog inspect exception
  exit()

raopSocket.bind config.metadataPort

##################
# Message handlers
##################

# Debug to console
messageEmitter.on 'message', (args) -> puts inspect args

# Send to Playlisttt
messageEmitter.on 'message', (args) ->
  request.post
    url: config.playlisttt.baseUrl + '/api/playlist'
    headers:
      'Authorization': "Bearer #{config.playlisttt.accessToken}"
    json:
      artist: args.artist
      title: args.title
      album: args.album
    timeout: 5000
  , (err, response) ->
    debugLog(err.toString()) if err?