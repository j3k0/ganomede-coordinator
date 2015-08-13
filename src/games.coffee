couchbone = require "./couchbone"
DB = require "./couchdb"
config = require "../config"

class Module
  constructor: () ->
    # GamesCouch instance
    @db = null

  initialize: (options = {}) ->
    @db = options.db
    if @db
      if options.callback
        options.callback null, @
    else
      DB.views = require './couchdb-views'
      DB.initialize config.couch, (err, ldb) =>
        @db = ldb
        if options.callback
          options.callback err, @

  newModel: (obj) ->
    new GameModel(obj, @db)

  activeGames: (type, username) -> new ActiveGames(type, username, @db)

  listenGames: (since = -1, callback) ->
    @db.pollChanges since, (err, polldata) =>
      if err || polldata.results.length == 0
      then callback err, polldata
      else
        ids = polldata.results
        .map    (x) -> x.id
        .filter (x) -> x[0] != "_"
        @db.fetch ids, (err, data) ->
          if err
            callback err
          else
            results = data.rows
            .filter (x) -> x?.doc?._id
            .map (x) -> x.doc
            .map fixId
            callback err,
              last_seq: polldata.last_seq
              results:  results

fixId = (x) ->
  x.id = x._id
  delete x._id
  delete x._rev
  x

# fields:
#
# - id: "1234"
# - type: "tri/v1"
# - status: "active" (inactive, gameover)
# - url: "http://..."
# - players: [ "u1", "u2" ]
#
class GameModel extends couchbone.Model
  constructor: (obj, db) ->
    super(obj, db)

  isValid: () ->
    return @type? and @isValidStatus(@status) and @url? and @players?.length

  isValidStatus: (status) ->
    return status == "active" or status == "inactive" or status == "gameover"

class GameCollection extends couchbone.Collection
  constructor: (type, username, db) ->
    super(db, GameModel)
    @type = type
    @username = username

class ActiveGames extends GameCollection
  constructor: (type, username, db) ->
    super(type, username, db)

    @design = config.couch.designName
    @view = "active_games"
    @fetchOptions.startkey = [ @type, @username ]
    @fetchOptions.endkey = [ @type, @username, {} ]

module.exports = Module
# vim: ts=2:sw=2:et:
