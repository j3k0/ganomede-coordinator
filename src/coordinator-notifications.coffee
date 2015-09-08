vasync = require 'vasync'
lodash = require 'lodash'
helpers = require 'ganomede-helpers'
config = require '../config'
log = require './log'

JOIN = 'join'
LEAVE = 'leave'

activePlayers = (game) ->
  unless game.waiting?.length
    return game.players

  return game.players.filter (username) ->
    game.waiting.indexOf(username) == -1

# Returns [helpers.Notification] for every player that should be notified
# about @playerInQuestion leaving/joining (@type) game @game.
createNotifications = (type, game, playerInQuestion) ->
  # Notify everyone except @playerInQuestion
  whoToNotify = activePlayers(game).filter (username) ->
    username != playerInQuestion

  return whoToNotify.map (username) ->
    n = new helpers.Notification({
      from: config.routePrefix
      to: username
      type: type
      data: {
        game: lodash.pick(game, ['id', 'type', 'players'])
        player: playerInQuestion
      }
    })

    return n

send = (sendFn, notifications, callback) ->
  iterator = (notification, cb) ->
    sendFn notification, (err, response) ->
      if (err)
        log.error 'coordinator-notifications: .send() failed',
          err: err
          notification: notification
          response: response

      # Ignore errors?
      cb(err, response)

  vasync.forEachParallel
    func: iterator
    inputs: notifications
  , (err, results) ->
    if callback instanceof Function
      callback(err, err || lodash.pluck(results.operations, 'result'))

module.exports = {
  join: createNotifications.bind(null, JOIN)
  leave: createNotifications.bind(null, LEAVE)
  send: send

  JOIN: JOIN
  LEAVE: LEAVE
}
