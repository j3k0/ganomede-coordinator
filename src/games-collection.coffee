couchbone = require "./couchbone"

class Module
  constructor: () ->
    # GamesCouch instance
    @db = null

  initialize: (options = {}) ->
    @db = options.db
    if !@db
      DB = require "games-couch.coffee"
      DB.initialize config.couch, (err, ldb) ->
        @db = ldb
        if options.callback
          options.callback err, @

  newModel: (obj) -> new GameModel(obj, @db)
  newCollection: (username) -> new GameCollection(username, @db)

# fields:
#
# - id: "1234"
# - type: "tri/v1"
# - status: "active" (inactive, gameover)
# - url: "http://..."
# - players: [ "u1", "u2" ]
#
class GameModel extends couchbone.Model
  constructor: (obj, pdb) ->
    super(obj, pdb || db)

  isValid: () ->
    return @type? and @isValidStatus(@status) and @url? and @players?.length

  isValidStatus: (status) ->
    return status == "active" or status == "inactive" or status == "gameover"

class GameCollection extends couchbone.Collection
  contructor: (username, pdb) ->
    @username = username
    super(pdb || db, GameModel)

module.exports = Module
# vim: ts=2:sw=2:et: