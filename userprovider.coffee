mongoose = require "mongoose"
conf = require "./conf"
bcrypt = require "bcrypt"

Schema = mongoose.Schema
ObjectId = Schema.ObjectId
UserSchema = new Schema ({})
User

passport = require 'passport'
LocalStrategy = require("passport-local").Strategy

MailChimpAPI = require("mailchimp").MailChimpAPI
MailChimpWebhook = require('mailchimp').MailChimpWebhook;
util = require "util"

LicenseSchema = new Schema
  name: String
  index: Number
  maxBandwidth: Number
  price: Number

QuerySchema = new Schema
  user: ObjectId
  date: Date
  length: Number
  url: String
  selector: String
  inner: Boolean

PromoSchema = new Schema
  code: String
  subscription: Number
  duration: Number
  expirationDate: Date
  discount: Number

addUserToMailchimp = (email, callback) ->
  mailchimp.listUnsubscribe { id: "85d2ccd197", email_address: email, delete_member: false, send_goodbye: false}, (error, data) ->
    mailchimp.listSubscribe { id: "85d2ccd197", email_address: email }, (error, data) ->
      if !data
        callback error.message
      else
        callback true

deleteUserFromMailchimp = (email, callback) ->
  mailchimp.listUnsubscribe { id: "85d2ccd197", email_address: email, delete_member: true, send_goodbye: true}, (error, data) ->
    if error
      callback false
    else
      callback true

UserSchema = new Schema
  email: type: String, unique: true
  hash: type: String, required: true
  salt: type: String, required: true
  subscription: type: Number, default: 0
  bandwidth: type: Number, default: 0
  lastBWUpdate: type: Date, default: Date.now
  emailConfirmed: type: Boolean, default: false

  recurringPaymentID: type: String
  promo: String

mongoose.model "User", UserSchema

db = mongoose.connect "mongodb://localhost/minusone"

User = mongoose.model "User"

mongoose.model "License", LicenseSchema
License = mongoose.model "License"

mongoose.model "Query", QuerySchema
Query = mongoose.model "Query"

mongoose.model "Promo", PromoSchema
Promo = mongoose.model "Promo"

mailchimp = new MailChimpAPI conf.mailchimp, { version : '1.3', secure : true }
webhook = new MailChimpWebhook()

passport.use new LocalStrategy {usernameField: 'email', passwordField: 'password'}, (email, password, done) ->
  findByEmail email, (user) ->
    if !user
      return done null, false, message: 'Unkown email'
    else
      verifyUserPassword user, password, (verified) ->
        if !verified
          return done null, false, message: "Invalid password"
        else
          return done null, user

UserProvider = ->

UserProvider.prototype.userInfo = (req, callback) ->
  if req.loggedIn
    callback()

UserProvider.prototype.findAll = (callback) ->
  User.find {}, (err, users) ->
    callback null, users

UserProvider.prototype.findById = (id, callback) ->
  User.findById id, (err, user) ->
    callback err, user

findByEmail = (email, callback) ->
  User.findOne email: email, (err, user) ->
    if !err
      callback user

UserProvider.prototype.modifyById = (id, callback) ->
  User.findById id, (err, user) ->
    if !err
      user.save (err) ->
        callback()

UserProvider.prototype.deleteById = (id, callback) ->
  User.findById id, (err, user) ->
    if !err
      deleteUserFromMailchimp user.email, (done) ->
        if done
          user.remove (err) ->
            console.log err
            callback()

###UserProvider.prototype.delete = (callback) ->
  User.find {}, (err, users) ->
    users.forEach (user) ->
      user.remove (err) ->
        callback()###

UserProvider.prototype.save = (user, callback) -> 
  user.save (err) ->
    callback err

UserProvider.prototype.saveUser = (email, password, callback) ->
  verifyRegisteringUser email, (cb) ->
    if cb is true
      salt = bcrypt.genSaltSync 10
      hash = bcrypt.hashSync password, salt
      user = new User email: email, hash: hash, salt: salt
      user.save (err) ->
        if !err
          addUserToMailchimp user.email, (done) ->
            if done
              findByEmail email, (user) ->
                callback null, user
            else
              callback done, null
        else
          callback err, null
    else
      callback cb, null

verifyRegisteringUser = (email, callback) ->
  findByEmail email, (user) ->
    if user isnt null
      error = "Your email " + email + " has already been registered."
      callback error
    else
      callback true

verifyUserPassword = (user, password, callback) ->
  bcrypt.compare password, user.hash, (err, res) ->
    callback res

UserProvider.prototype.saveLicense = (name, index, maxBandwidth, price, callback) ->
  license = new License name: name, index: index, maxBandwidth: maxBandwidth, price: price
  license.save (err) ->
    if err
      throw err
    else
      callback()

UserProvider.prototype.findLicenseById = (index, callback) ->
  License.findOne index: index, (err, license) ->
    if !err
      callback license
    else
      console.log err

UserProvider.prototype.getUserBandwidth = (id, callback) ->
  User.findById id, (err, user) ->
    if !err
      bandwidth = user.bandwidth  
      callback bandwidth
    else
      console.log err

UserProvider.prototype.getUserSubscription = (id, callback) ->
  User.findById id, (err, user) ->
    if !err
      callback user.subscription
    else
      console.log err

UserProvider.prototype.getLicenseMaxBandwidth = (index, callback) ->
  License.findOne index: index, (err, license) ->
    if !err
      maxBandwidth = license.maxBandwidth
      callback maxBandwidth
    else
      console.log err

UserProvider.prototype.getLicenseMaxBandwidth = (index, callback) ->
  License.findOne index: index, (err, license) ->
    if !err
      maxBandwidth = license.maxBandwidth
      callback maxBandwidth
    else
      console.log err

UserProvider.prototype.getQueriesByUser = (id, callback) ->
  Query.find user: id, (err, queries) ->
    if !err
      callback queries
    else
      console.log err

UserProvider.prototype.getQueriesByDate = (date, callback) ->
  Query.find date: date, (err, queries) ->
    if !err
      callback queries
    else
      console.log err

UserProvider.prototype.getQueriesByUrl = (id, callback) ->
  Query.find url: url, (err, queries) ->
    if !err
      callback queries
    else
      console.log err

UserProvider.prototype.getTotalQueries = (callback) ->
  Query.find {}, (err, queries) ->
    if !err
      callback queries
    else
      console.log err

UserProvider.prototype.getTotalBandwidthUsed = (callback) ->
  Query.find {}, (err, queries) ->
    if !err
      i = 0
      total = 0
      while i < queries.length
        total += queries[i].length
        i++
      callback total
    else
      console.log err

UserProvider.prototype.getTotalNumOfQueries = (callback) ->
  Query.find {}, (err, queries) ->
    if !err
      callback queries.length
    else
      console.log err

UserProvider.prototype.getQueriesByUserAndUrl = (id, url, callback) ->
  Query.find
    user: id
    url: url
    , (err, queries) ->
      if !err
        callback queries
      else
        console.log err

UserProvider.prototype.getQueriesByUserAndDate = (id, date, callback) ->
  Query.find
    user: id
    date: date
    , (err, queries) ->
      if !err
        callback queries
      else
        console.log err

UserProvider.prototype.getQueriesByUserAndDateInterval = (id, date1, date2, callback) ->
  Query.find
    user: id
    date:
      $gte: date1
      $lte: date2
    , (err, queries) ->
      if !err
        callback queries
      else
        console.log err

UserProvider.prototype.saveQuery = (user, url, selector, inner, length, date, callback) ->
  query = new Query
    user: user
    url: url
    length: length
    date: date
    selector: selector
    inner: inner
  query.save (err) ->
    if err
      console.log err
      throw err
    else
      callback()

resetBandwidth = (user, callback) ->
  user.bandwidth = 0
  user.lastBWUpdate = new Date()
  user.save (err) ->
    if err
      callback err

setUserSubscription = (id, plan, callback) ->
  User.findById id, (err, user) ->
    if !err
      user.subscription = plan
      user.save (err) ->
        callback err
    else
      callback err

UserProvider.prototype.addUserToMailchimp = addUserToMailchimp

UserProvider.prototype.findByEmail = findByEmail

UserProvider.prototype.resetBandwidth = resetBandwidth

UserProvider.prototype.setUserSubscription = setUserSubscription

exports.UserProvider = UserProvider
