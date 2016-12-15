log = require "./log"
authdb = require "authdb"
restify = require "restify"
helpers = require 'ganomede-helpers'
config = require '../config'
gameServers = require './game-servers'
notifications = require './coordinator-notifications'

sendError = (err, next) ->
  log.error err
  next err

class CoordinatorApi
  constructor: (options = {}) ->

    # configure authdb client
    @authdbClient = options.authdbClient || authdb.createClient(
      host: config.authdb.host
      port: config.authdb.port)

    # games collection
    @games = options.games

    @gameServers = options.gameServers || gameServers

    # function for sending out notifications
    @sendNotification = options.sendNotification ||
      helpers.Notification.sendFn()

  addRoutes: (prefix, server) ->

    #
    # Middlewares
    #

    # Populates req.params.user with value returned from authDb.getAccount()
    authMiddleware = helpers.restify.middlewares.authdb.create({
      authdbClient: @authdbClient,
      secret: config.apiSecret
    })

    # Check the API secret key validity
    secretMiddleware = (req, res, next) =>
      if req.params.secret != config.apiSecret
        err = new restify.UnauthorizedError('not authorized')
        return sendError(err, next)
      delete req.params.secret
      next()

    # Populates req.params.game with the GameModel of ID given by req.params.id
    gameMiddleware = (req, res, next) =>
      if !req.params.id
        err = new restify.InvalidContentError('invalid content')
        return sendError(err, next)
      game = @games.newModel id:req.params.id
      game.fetch (err) ->
        if err
          log.error err
          return sendError err, next
        username = req.params.user.username
        if !(true for p in game.players when p == username).length
          err = new restify.UnauthorizedError('not authorized')
          return sendError err, next
        req.params.game = game
        next()

    #
    # API Calls
    #

    # GET /active-games
    getActiveGames = (req, res, next) =>
      type = "#{req.params.type}/#{req.params.version}"
      collection = @games.activeGames type, req.params.user.username
      collection.fetch (err) ->
        if err
          return sendError err, next
        res.send (m.toJSON() for m in collection.models)
        next()

    # GET /games/:id
    getGame = (req, res, next) =>
      res.send req.params.game.toJSON()
      next()

    # POST /games
    postGame = (req, res, next) =>
      body = req.body
      hasPlayers = body?.players?.length
      username = req.params.user.username
      if (!hasPlayers or body.players[0] != username)
        err = new restify.InvalidContentError('invalid content')
        return sendError err, next
      model = @games.newModel
        status: "inactive"
        url: @gameServers.random()
        type: "#{req.params.type}/#{req.params.version}"
        players: req.body.players
        waiting: (p for p in body.players when p != username)
      if model.waiting.length == 0
        model.status = "active"
      model.save (err) ->
        if err
          return sendError(err, next)
        res.send model.toJSON()
        next()

    saveGame = (req, res, next) =>
      game = req.params.game
      game.save (err) =>
        if err
          return sendError(err, next)

        # send out notifications if there are any
        if req.params.notifications?.length
          notifications.send(@sendNotification, req.params.notifications)

        res.send game.toJSON()
        next()

    # POST /games/:id/join
    postJoin = (req, res, next) =>
      username = req.params.user.username
      game = req.params.game
      isInactive = (game.status == "inactive")
      if !game.waiting
        game.waiting = []
      isWaiting = (true for p in game.waiting when p == username).length
      if !isInactive or !isWaiting
        err = new restify.ForbiddenError('Player not waiting')
        return sendError err, next
      game.waiting = (p for p in game.waiting when p != username)
      if game.waiting.length == 0
        delete game.waiting
        game.status = "active"

      req.params.notifications = notifications.join(game, username)
      next()

    # POST /games/:id/leave
    postLeave = (req, res, next) =>
      username = req.params.user.username
      game = req.params.game
      if game.status == "active" or game.status == "inactive"
        if !game.waiting
          game.waiting = []
        isWaiting = (true for p in game.waiting when p == username).length
        if isWaiting
          err = new restify.ForbiddenError('Player already waiting')
          return sendError err, next
        game.waiting.push username
        game.status = "inactive"
      else if game.status == "gameover"
        # remove from viewers
        game.viewers = (p for p in game.viewers when p != username)
      else
        err = new restify.InternalError('Invalid game state')
        return sendError err, next

      req.params.notifications = notifications.leave(game, username)
      if req.body?.reason
        req.params.notifications.forEach (n) ->
          n.data.reason = req.body.reason
          if n.data.reason == "resign"
            n.data.push =
              app: game.type
              title: [ "opponent_has_left_title" ]
              message: [ "opponent_has_left_message", username ]
      next()

    # POST /games/:id/gameover
    postGameOver = (req, res, next) =>
      username = req.params.user.username
      game = req.params.game
      if !req.body?.gameOverData
        err = new restify.InvalidContentError(
          'invalid content: missing gameOverData')
        return sendError err, next
      game.gameOverData = req.body.gameOverData
      game.status = "gameover"
      game.viewers = game.players
      game.date = +new Date()
      next()

    sendJson = (data, res, next) ->
      res.json data
      next()

    isOver = (doc) -> doc.status == "gameover"

    gamesThatAreOver = (docs) ->
      last_seq: docs.last_seq
      results: docs.results.filter isOver

    listenGameover = (req, res, next) =>
      options =
        since: req.params.since
        limit: req.params.limit || 2048
      @games.listenGames options, (err, value) ->
        if err
        then sendError err, next
        else sendJson gamesThatAreOver(value), res, next

    server.get "#{prefix}/auth/:authToken/games/:id",
      authMiddleware, gameMiddleware, getGame

    server.post "#{prefix}/auth/:authToken/games/:id/join",
      authMiddleware, gameMiddleware, postJoin, saveGame

    server.post "#{prefix}/auth/:authToken/games/:id/leave",
      authMiddleware, gameMiddleware, postLeave, saveGame

    server.post "#{prefix}/auth/:authToken/games/:id/gameover",
      authMiddleware, gameMiddleware, postGameOver, saveGame

    root = "/#{prefix}/auth/:authToken/:type/:version"
    server.get "#{root}/active-games", authMiddleware, getActiveGames
    server.post "#{root}/games", authMiddleware, postGame

    server.get "#{prefix}/gameover", secretMiddleware, listenGameover

module.exports =
  create: (options = {}) -> new CoordinatorApi(options)

# vim: ts=2:sw=2:et:
