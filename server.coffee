restify = require "restify"
request = require "request"
util = require "util"
url = require "url"
fs = require "fs"
path = require "path"
UserProvider = require("./userprovider").UserProvider
userprovider = new UserProvider()
cheerio = require "cheerio"
bcrypt = require "bcrypt"
monkey_response = require("http").ServerResponse

original_writeHead = monkey_response.prototype.writeHead
monkey_response.prototype.writeHead = ->
  default_headers = this.getHeader "Access-Control-Allow-Headers"
  if default_headers
    this.setHeader "Access-Control-Allow-Headers", default_headers + ", Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Key, X-Api-Version"
  original_writeHead.apply this, arguments

debug = false
debugFlag = process.argv[2]
if typeof debugFlag isnt 'undefined' and debugFlag is 'debug'
  debug = true

process.on "uncaughtException", (err) ->
  if !debug
    console.log "server " + err
    console.log "Node NOT Exiting..."

if debug
  reqTime = 0

reply = (req, res) ->
  
  console.log "yeah"
  if debug
    startTime = new Date().getTime()
  
  uri = decodeURIComponent "http://#{req.params.url}"
  part = decodeURIComponent req.params.part
  inner = req.params.inner
  key = req.header "X-Api-Key"
  changeBw = true

  if key.indexOf(",") isnt -1
    keys = key.split ","
    if bcrypt.compareSync("yourownpersonalkey", keys[1])
      changeBw = false
      key = keys[0]

  userprovider.findById key, (err, user) ->
    if !err and user
      if user.emailConfirmed
        userprovider.findLicenseById user.subscription, (license) ->
          # HACK: licence.maxBandwidth is type object (it should be number)
          bandwidth = Number(user.bandwidth)
          if !changeBw
            maxBandwidth = 0
          else
            maxBandwidth = Number(license.maxBandwidth)
          if bandwidth < maxBandwidth or maxBandwidth is 0
            # Everything is right!
            getHTTP uri, part, inner, (data) ->
              if 'undefined' is typeof data.error
                res.send data
                if changeBw
                  bandwidth += data.length
                  user.bandwidth = bandwidth
                  userprovider.save user, ->
                    userprovider.saveQuery key, uri, part, inner, data.length, new Date().getTime()
                if debug
                  elapsed = new Date().getTime() - startTime
                  seconds = elapsed * 0.001
                  console.log "Total time: #{seconds} seconds"
                  time = Number(seconds-reqTime)
                  console.log "Time taken by -1: #{time}"
                  log time
              else
                res.send 403, error: data.error
          else
            res.send 403, error: "You have reached your license's bandwidth limit"
      else
        res.send 403, error: "You must confirm your email before using HolaIO"
    else
      res.send 403, error: "Your API key is not correct"

replaceAll = (text, s, r) ->
  while text.toString().indexOf s != -1
      text = text.toString().replace s,r
  return text

# Make an HTTP request, get content and select the part of the web we want
getHTTP = (uri, selectors, inner, callback) ->
  startreqTime = new Date().getTime()
  try
    request uri: uri, encoding: 'binary', (error, response, body) ->
      if !error && response.statusCode == 200
        if debug
          elapsed = new Date().getTime() - startreqTime;
          reqTime = elapsed * 0.001
          console.log "Time of request: #{reqTime} seconds"
       
        selectorArray = selectors.split ","
        json = {}
        $ = cheerio.load body
        selectorArray.forEach (element) ->
          array = new Array()
          if element.indexOf(":nth-child(") isnt -1
            element = element.replace /[ ]/g, ""
            elArray = element.split ">"
            tag = ""
            sel = element
            if elArray[0].indexOf("#") isnt -1
              tag = elArray[0]
            else
              tag = elArray[0].split(":")[0]
              sel = element.replace /:nth-child\((.*?)\)/i, ''
            tag = tag.toLowerCase()
            sel = sel.replace /\>([A-Z][A-Z0-9]*)/ig, ''
            i = 0
            while i < sel.match(/(.*?):nth-child\((.*?)\)/ig).length
              sel = "$(" + sel
              i++
            sel = sel.replace /(.*?):nth-child\((.*?)\)/ig, '$1.children()[$2-1])'
            sel = sel.toLowerCase()
            sel = sel.replace tag, 'elem'
            $(tag).each (index, elem) ->
              elem = $(this)
              if inner is "true" or inner is "inner"
                array.push eval sel+".html()"
              else
                array.push eval "$.html("+sel+")"
            json[element] = array
          else
            $(element).each (index, elem) ->
              if inner is "true" or inner is "inner"
                array.push $(this).html()
              else
                $this = $(this)
                array.push $.html($this)
            json[element] = array
        callback json
      else if error
        return error: error
  catch er
    return error: er

# Do some time logging
log = (time) ->
  stream = fs.createWriteStream "log", flags: "a", encoding: "encoding", mode: 0o666
  stream.once "open", (fd) ->
    stream.write time+"\n"

# Start the server
# NOTE: As we're using Nginx as proxy, we don't need SSL here because Nginx does the job
server = restify.createServer name: "HolaIO", version: "1.0.0"#, key: fs.readFileSync("certs/key.pem"), certificate: fs.readFileSync("certs/certificate.pem")

server.use restify.acceptParser server.acceptable
server.use restify.queryParser()
server.use restify.bodyParser()

server.get "/io/:url/:part/:inner", reply

server.get "/:url/:part/:inner", reply

if !debug
  server.listen 1516, ->
    console.log "API server listening at %s", server.url
else
  server.listen 2021, ->
    console.log "API server listening at %s", server.url

process.on "SIGTERM", ->
  server.close()
  process.exit 0
