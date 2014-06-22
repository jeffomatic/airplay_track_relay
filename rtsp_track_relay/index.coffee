#!/usr/bin/env coffee
_ = require('underscore')
deep = require('deep')
dgram = require('dgram')
events = require('events')
request = require('request')

{puts, inspect} = require('util')
rtspIncomingSocket = dgram.createSocket("udp4")

config =
  debug: false
  debounceTime: 5000
  rtspIncomingPort: 12345
  targetUrl: 'http://localhost:3333/now-playing'
  playlisttt:
    accessToken: process.env.PLAYLISTTT_ACCESS_TOKEN

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

rtspIncomingSocket.on "message", (msg, rinfo) ->
  currentByte = 0;
  debugLog "Message Received: #{inspect rinfo}\n\n #{msg.toString()}"

  headerCount = msg.readInt32LE(currentByte);
  currentByte += 4;
  debugLog "HEADER COUNT: #{headerCount}"

  headers = {}

  for i in [0...headerCount]
    nameLength = msg.readInt32LE(currentByte);
    currentByte += 4
    nameBuf = new Buffer(nameLength)
    msg.copy nameBuf, 0, currentByte, currentByte + nameLength
    currentByte += nameLength

    valueLength = msg.readInt32LE(currentByte);
    currentByte += 4
    valueBuf = new Buffer(valueLength)
    msg.copy valueBuf, 0, currentByte, currentByte + valueLength
    currentByte += valueLength

    headers[nameBuf.toString()] = valueBuf.toString()

  debugLog "HEADERS: #{inspect headers}"

  contentLength = msg.readInt32LE(currentByte)
  currentByte += 4;
  debugLog "CONTENT LENGTH: #{contentLength}"

  content = new Buffer(contentLength)
  msg.copy content, 0, currentByte, currentByte + contentLength
  currentByte += contentLength
  debugLog "CONTENT: #{content.toString()}"

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

  rawTags = {}
  transformedTags = {}

  # Parse contents
  if headers['Content-Type'] == 'application/x-dmap-tagged'
    debugLog "<<DMAP CONTENT"
    currentContentByte = 0

    while currentContentByte < contentLength
      debugLog "<<TAG"
      # Tag
      rawTag = new Buffer(4)
      content.copy rawTag, 0, currentContentByte, currentContentByte + 4
      currentContentByte += 4
      debugLog "Tag: #{rawTag}"

      # Tag data size
      tagDataSize = content.readInt32BE(currentContentByte)
      currentContentByte += 4
      debugLog "Tag data size: #{tagDataSize}"

      if containers.indexOf(rawTag.toString()) >= 0
        debugLog "CONTAINER!"
      else
        # Tag data
        rawData = new Buffer(tagDataSize)
        content.copy rawData, 0, currentContentByte, currentContentByte + tagDataSize
        currentContentByte += tagDataSize
        debugLog "Tag data: #{rawData}"

        # Collect tags
        debugLog rawTag.toString()
        rawTags[rawTag.toString()] = rawData.toString()

        # Transform tag titles if necessary
        if transformed = tagTransform[rawTag.toString()]
          transformedTags[transformed] = rawData.toString()

      debugLog "TAG>>"

    debugLog "DMAP CONTENT>>"

  method = new Buffer(16)
  msg.copy method, 0, currentByte, currentByte + 16
  currentByte += 16
  debugLog "METHOD: #{method}"

  if Object.keys(transformedTags).length > 0 \
  && method.toString().indexOf('SET_PARAMETER') >= 0 \
  && rawTags.astm? # Pause events don't include the astm tag
    debugLog inspect transformedTags
    announceMessage transformedTags

rtspIncomingSocket.on "listening", ->
  {address, port} = @address()
  debugLog "RTSP socket started on #{address}:#{port}"

rtspIncomingSocket.on "close", ->
  {address, port} = @address()
  debugLog "RTSP socket closed on #{address}:#{port}"
  exit()

rtspIncomingSocket.on "error", (exception) ->
  debugLog "RTSP socket error"
  debugLog inspect exception
  exit()

rtspIncomingSocket.bind config.rtspIncomingPort

##################
# Message handlers
##################

# Debug to console
messageEmitter.on 'message', (args) -> puts inspect args

# Send to Playlisttt
messageEmitter.on 'message', (args) ->
  request.post
    url: 'http://playlisttt.ifttt.com/ifttt/v1/actions/add_song'
    headers:
      'Authorization': "Bearer #{config.playlisttt.accessToken}"
    json:
      actionFields:
        artist: args.artist
        title: args.title
        album: args.album
    timeout: 5000
  , (err, response) ->
    debugLog(err.toString()) if err?