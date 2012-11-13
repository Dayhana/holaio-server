express = require "express"
bcrypt = require "bcrypt"
fs = require "fs"

UserProvider = require("./userprovider").UserProvider
userprovider = new UserProvider()
passport = require 'passport'
LocalStrategy = require("passport-local").Strategy
flash = require 'connect-flash'
require "express-namespace"
nodemailer = require "nodemailer"

conf = require("./conf")
panelroot = conf.root
mailchimpKey = conf.mailchimp

debug = false
debugFlag = process.argv[2]
if typeof debugFlag isnt 'undefined' and debugFlag is 'debug'
  debug = true

process.on "uncaughtException", (err) ->
  if !debug
    console.log "web " + err
    console.log "Node NOT Exiting..."

passport.serializeUser (user, done) ->
  done null, user.id

passport.deserializeUser (id, done) ->
  userprovider.findById id, (err, user) ->
    done err, user

app = express()
app.configure ->
  app.set "views", __dirname + "/views"
  app.set "view engine", "jade"
  app.use express.cookieParser "OurPersonalSecretKey"
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.session()
  app.use flash()
  app.use passport.initialize()
  app.use passport.session()
  app.basepath = panelroot
  app.use panelroot, express.static(__dirname + "/public")
  app.use app.router
  app.use express.favicon(__dirname + "/public/holadesk_favicon.png")

app.settings.mongoUrl = "mongodb://localhost/holaio"

app.namespace panelroot, ->

  app.get "/", (req, res) ->
    if req.isAuthenticated()
      user = req.user
      if user.emailConfirmed
        if req.query.new
          newUser = true
        userprovider.getUserBandwidth user._id, (bw) ->
          bandwidth = Number(bw)
          userprovider.getUserSubscription user._id, (sub) ->
            userprovider.getLicenseMaxBandwidth sub, (maxBw) ->
              maxBandwidth = Number(maxBw)
              days = 30
              today = new Date()
              thatday = new Date today.getTime() - (days * 24 * 60 * 60 * 1000)
              userprovider.getQueriesByUserAndDateInterval req.user._id, thatday, today, (queries) ->
                res.render "panel"
                  user: user
                  bandwidth: bandwidth
                  maxBandwidth: maxBandwidth
                  newuser: newUser
                  queries: queries
      else
        res.redirect panelroot+"/devconfirmemailhemust"
    else
      res.redirect panelroot+"/login"

  app.get '/login', (req, res) ->
    if !req.isAuthenticated()
      error = req.flash 'error'
      res.render 'login'
        user: req.user
        message: error[0]
    else
      res.redirect panelroot+'/'

  app.post '/login', passport.authenticate 'local', {failureRedirect: panelroot+'/login', successRedirect: panelroot+'/', failureFlash: true}

  app.get '/register', (req, res) ->
    if !req.isAuthenticated()
      errors = if typeof req.query.errors isnt "undefined" then req.query.errors.split "," else ""
      console.log errors
      res.render 'register'
        user: req.user
        errors: errors
    else
      res.redirect panelroot+'/'

  app.post 'register', (req, res) ->
    userprovider.saveUser req.body.email, req.body.password, (err, user) ->
      console.log err
      if !err
        res.redirect panelroot+"/devconfirmemailhemust"
      else
        console.log err
        res.redirect panelroot+"/register?errors="+err

  app.get "/logout", (req, res) ->
    req.logout()
    res.redirect panelroot+"/"

  app.get "/register/:num", (req, res) ->
    num = req.params.num
    if num > 0 and num <= 5
      res.render "register"
        user: req.user
        value: num
    else
      res.render "register"

  app.get "/demo", (req, res) ->
    if req.isAuthenticated()
      userprovider.findById req.user._id, (err, user) ->
        if user.emailConfirmed
          key = generateKey(req.user._id)
          res.render "demo"
            user: req.user
            id: key
        else
          res.redirect panelroot+"/devconfirmemailhemust"
    else
      res.redirect panelroot+"/login"

  generateKey = (id) ->
    salt = bcrypt.genSaltSync 10
    hash = bcrypt.hashSync "yourownpersonalkey", salt
    key = id + ',' + hash
    return key

  app.get "/selector", (req, res) ->  
    if req.isAuthenticated()
      userprovider.findById req.user._id, (err, user) ->
        if user.emailConfirmed
          key = generateKey(req.user._id)
          res.render "selector"
            user: req.user
            id: key
        else
          res.redirect panelroot+"/devconfirmemailhemust"
    else
      res.redirect panelroot+"/login"

  app.get "/forgot", (req, res) ->
    if !req.isAuthenticated()
      res.render "forgot"
        user: req.user
    else
      res.redirect panelroot+"/"

  random = `function () {
    var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
    var string = "";
    for (i=0; i<8; i++) {
      var rnum = Math.floor(Math.random() * chars.length);
      string += chars.substring(rnum, rnum+1);
    }
    return string;
  }`

  app.post "/forgot", (req, res) ->
    email = req.body.email
    userprovider.findByEmail email, (err, user) ->
      if user != null
        if user.emailConfirmed
          password = random()

          salt = bcrypt.genSaltSync 10
          hash = bcrypt.hashSync password, salt
          user.salt = salt
          user.hash = hash

          userprovider.save user, (err) ->
            if err
              console.log err
            else
              emailBody = fs.readFileSync "public/forgotemail.html", "utf8"
              emailBodyPlain = "Hi,\nWe were told that you forgot your password, so we created a new one for you, it's $PASSWORD\nLog in: http://io.holalabs.com/panel/login"
              smtpTransport = nodemailer.createTransport "SMTP",
                service: "Gmail"
                auth:
                  user: "admin@holalabs.com"
                  pass: "hol4l4bs15"

              mailOptions =
                  from: "HolaIO <no-reply@holalabs.com>"
                  to: email
                  subject: "Your new HolaIO password"
                  text: emailBodyPlain.replace "$PASSWORD", password
                  html: emailBody.replace "$PASSWORD", password

              smtpTransport.sendMail mailOptions, (error, response) ->
                if error
                    res.render "forgot"
                      errors: [err]
                      user: req.user
                else
                    res.render "forgot"
                      sent: true
                      user: req.user
                smtpTransport.close()
        else
          res.redirect panelroot+"/devconfirmemailhemust"
      else
        res.render "forgot", errors: [email + " isn't in our database"]

  app.get "/account", (req, res) ->
    if req.isAuthenticated()
      userprovider.findById req.user._id, (err, user) ->
        if user.emailConfirmed
          if typeof req.param('success') isnt 'undefined'
            res.render "account"
              user: req.user
              success: true
          else if typeof req.param('error') isnt 'undefined'
            res.render "account"
              user: req.user
              errors: [req.param('error')]
          else
            res.render "account"
              user: req.user
        else
          res.redirect panelroot+"/devconfirmemailhemust"
    else
      res.redirect panelroot+"/login"

  app.post "/account", (req, res) ->
    userprovider.findById req.user._id, (err, user) ->
      if req.body.password != ""
        salt = bcrypt.genSaltSync 10
        hash = bcrypt.hashSync req.body.password, salt
        user.salt = salt
        user.hash = hash
      userprovider.save user, (err) ->
        if err
          res.redirect panelroot+"/account?error="+encodeURIComponent(err)
        else
          res.redirect panelroot+"/account?success"

  app.get "/remove", (req, res) ->
    if req.isAuthenticated()
      userprovider.findById req.user._id, (err, user) ->
        if user.emailConfirmed
          res.render "remove"
            user: req.user
        else
          res.redirect panelroot+"/devconfirmemailhemust"
    else
      res.redirect panelroot+"/"

  app.post "/remove", (req, res) ->
    userprovider.deleteById req.user._id, ->
        res.redirect panelroot+"/"
  
  app.get "/bandwidth", (req, res) ->
      userprovider.getTotalBandwidthUsed (bandwidth) ->
        res.send bandwidth.toString()

  app.get "/queries", (req, res) ->
    userprovider.getTotalNumOfQueries (num) ->
      res.send num.toString()
      
  app.get "/devconfirmemailhemust", (req, res) ->
    if req.isAuthenticated()
      userprovider.findById req.user._id, (err, user) ->
        if user.emailConfirmed
          res.redirect panelroot+"/"
        else
          if typeof req.param('success') isnt 'undefined'
            res.render "confirm"
              success: true
              user: req.user
          else if typeof req.param('error') isnt 'undefined'
            res.render "confirm"
              errors: [req.param('error')]
              user: req.user
          else
            res.render "confirm"
              user: req.user
    else
      res.redirect panelroot+"/login"

  app.post "/confirmEmail", (req, res) ->
    if req.body.type is "subscribe"
      userprovider.findByEmail req.body.data.email, (err, user) ->
        user.emailConfirmed = true
        userprovider.save user, (err) ->
          if err
            console.log err

  app.get "/sendSubscribeEmail", (req, res) ->
    if req.isAuthenticated()
      userprovider.addUserToMailchimp req.user.email, (err) ->
          res.render "confirm"
            sucess: true
            user: req.user
    else
      res.redirect panelroot+"/login"

  app.get "*", (req, res) ->
    res.render "404"
      user: req.user

if !debug
  server = app.listen 1616
  server.listen 1616, ->
    console.log "Listening on port " + server.address().port
else 
  server = app.listen 2121
  server.listen 2121, ->
    console.log "Listening on port " +server.address().port
