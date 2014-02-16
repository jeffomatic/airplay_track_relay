#!/usr/bin/env coffee
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

debugLog = (args...) ->
  return unless config.debug
  puts args...

debounce = (targetFunc) ->
  prevArgs = null
  prevTime = 0

  (args...) ->
    now = Date.now()

    return if (now - prevTime) < config.debounceTime || deep.equals(args, prevArgs)

    prevTime = now
    prevArgs = args
    targetFunc args...

messageEmitter = new events.EventEmitter
announceMessage = debounce (args) ->
  messageEmitter.emit 'message', args

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

  tags = {}

  # Parse contents
  if headers['Content-Type'] == 'application/x-dmap-tagged'
    debugLog "<<DMAP CONTENT"
    currentContentByte = 0

    while currentContentByte < contentLength
      debugLog "<<TAG"
      # Tag
      tag = new Buffer(4)
      content.copy tag, 0, currentContentByte, currentContentByte + 4
      currentContentByte += 4
      debugLog "Tag: #{tag}"

      # Tag data size
      tagDataSize = content.readInt32BE(currentContentByte)
      currentContentByte += 4
      debugLog "Tag data size: #{tagDataSize}"

      if containers.indexOf(tag.toString()) >= 0
        debugLog "CONTAINER!"
      else
        # Tag data
        data = new Buffer(tagDataSize)
        content.copy data, 0, currentContentByte, currentContentByte + tagDataSize
        currentContentByte += tagDataSize
        debugLog "Tag data: #{data}"

        # Collect relevant tags
        debugLog tag.toString()
        if transformed = tagTransform[tag.toString()]
          tags[transformed] = data.toString()

      debugLog "TAG>>"

    debugLog "DMAP CONTENT>>"

  method = new Buffer(16)
  msg.copy method, 0, currentByte, currentByte + 16
  currentByte += 16
  debugLog "METHOD: #{method}"

  if Object.keys(tags).length > 0 && method.toString().indexOf('SET_PARAMETER') >= 0
    debugLog inspect tags
    message = tags
    message.ts = (Date.now() / 1000) | 0
    announceMessage tags

rtspIncomingSocket.on "listening", ->
  {address, port} = @address()
  debugLog "Socket started on #{address}:#{port}"

rtspIncomingSocket.on "close", ->
  {address, port} = @address()
  debugLog "Socket closed on #{address}:#{port}"
  exit()

rtspIncomingSocket.on "error", (exception) ->
  debugLog "Oh noes! We've crashed."
  debugLog inspect exception
  exit()

rtspIncomingSocket.bind config.rtspIncomingPort

messageEmitter.on 'message', (args) -> puts inspect args
messageEmitter.on 'message', (args) ->
  request.post
    url: config.targetUrl
    json: args
    timeout: 5000
  , (err, response) ->
    puts err.toString() if err?