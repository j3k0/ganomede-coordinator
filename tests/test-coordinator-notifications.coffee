expect = require 'expect.js'
helpers = require 'ganomede-helpers'
lodash = require 'lodash'
notifications = require '../src/coordinator-notifications'
config = require '../config'

describe 'Coordinator Notifications', () ->
  playerJoining = 'joiner'
  playerLeaving = 'leaver'
  inactivePlayer = 'inactive-player'
  activePlayer = 'active-player'
  game = {
    id: 'game-id'
    type: 'game-type/v1'
    players: [playerJoining, playerLeaving, activePlayer, inactivePlayer]
    waiting: [playerLeaving, inactivePlayer]
  }

  testNotification = (n, expectedType, expectedData={}) ->
    expect(n).to.be.a(helpers.Notification)
    expect(n.type).to.be(expectedType)
    expect(n.from).to.be(config.routePrefix)
    for own key, val of expectedData
      compareMethod = if typeof val == 'object' then 'eql' else 'be'
      expect(n.data[key]).to[compareMethod](val)

  it 'creates correct `join` notifications', () ->
    for n in notifications.join(game, playerJoining)
      testNotification(n, notifications.JOIN, {
        game: lodash.pick(game, 'id', 'type', 'players')
        player: playerJoining
      })

  it 'creates correct `leave` notifications', () ->
    for n in notifications.leave(game, playerLeaving)
      testNotification(n, notifications.LEAVE, {
        game: lodash.pick(game, 'id', 'type', 'players')
        player: playerLeaving
        reason: 'resign'
      })

  it 'creates notifications only for active players
      except the one joining/leaving',
  () ->
    n1 = notifications.join(game, playerJoining)
    usersToBeNotifiedOfJoin = lodash.pluck(n1, 'to')
    expect(usersToBeNotifiedOfJoin).to.eql([activePlayer])

    n2 = notifications.join(game, playerLeaving)
    usersToBeNotifiedOfLeave = lodash.pluck(n2, 'to')
    expect(usersToBeNotifiedOfLeave).to.eql([playerJoining, activePlayer])
