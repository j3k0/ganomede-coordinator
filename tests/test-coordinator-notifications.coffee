expect = require 'expect.js'
helpers = require 'ganomede-helpers'
lodash = require 'lodash'
notifications = require '../src/coordinator-notifications'
config = require '../config'

describe 'Coordinator Notifications', () ->
  playerJoining = 'joiner'
  playerLeaving = 'leaver'
  game = {
    id: 'game-id'
    type: 'game-type/v1'
    players: [playerJoining, playerLeaving, 'other-guy']
    waiting: [playerLeaving]
  }

  testNotification = (n, expectedType, expectedData={}) ->
    expect(n).to.be.a(helpers.Notification)
    expect(n.type).to.be(expectedType)
    expect(n.from).to.be(config.routePrefix)
    for own key, val of expectedData
      compareMethod = if typeof val == 'object' then 'eql' else 'be'
      expect(n.data[key]).to[compareMethod](val)

  describe '.join()', () ->
    it 'creates correct `join` notifications', () ->
      for n in notifications.join(game, playerJoining)
        testNotification(n, notifications.JOIN, {
          game: lodash.pick(game, 'id', 'type', 'players')
          player: playerJoining
        })

    it 'creates `join` notification for every active player
        except the one joining',
    () ->
      n = notifications.join(game, playerJoining)
      usersToBeNotified = lodash.pluck(n, 'to')
      usersExpectedToBeNotified = game.players.filter (u) -> u != playerJoining
      expect(usersToBeNotified).to.eql(usersExpectedToBeNotified)

  describe '.leave()', () ->
    it 'creates correct `leave` notifications', () ->
      for n in notifications.leave(game, playerLeaving)
        testNotification(n, notifications.LEAVE, {
          game: lodash.pick(game, 'id', 'type', 'players')
          player: playerLeaving
          reason: 'resign'
        })

    it 'creates `leave` notifications for every active player
        except the one joining',
    () ->
      n = notifications.leave(game, playerLeaving)
      usersToBeNotified = lodash.pluck(n, 'to')
      usersExpectedToBeNotified = game.players.filter (u) -> u != playerLeaving
      expect(usersToBeNotified.sort()).to.eql(usersExpectedToBeNotified.sort())
