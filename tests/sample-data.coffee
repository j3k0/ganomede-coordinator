config = require '../config'

createGame = (id, p1, p2) ->
  _id: id
  type: "rule/v1",
  players: [ p1, p2 ]
  status: "active"
  url: "http://fovea.cc"

docs = [
  createGame "0000000000000000001", "p1", "p2"
  createGame "0000000000000000002", "p3", "p1"
  createGame "0000000000000000003", "p2", "p3"
]

for i in [1..100]
  docs.push createGame "x100#{i}", "p100", "pp#{i}"

module.exports =
  docs: docs

  users:
    p1:
      token: 'p1-token'
      account: {username: 'p1'}
    p2:
      token: 'p2-token'
      account: {username: 'p2'}
    p3:
      token: 'p3-token'
      account: {username: 'p3'}

  postGame:
    players: [ 'p1', 'p2' ]
  postGameRes:
    players: [ 'p1', 'p2' ]
    waiting: [ 'p2' ]
    type: 'rule/v1'
    status: "inactive"
    url: config.gameServers[0]
  postGameRes2:
    players: [ 'p1', 'p2' ]
    type: 'rule/v1'
    status: "active"
    url: config.gameServers[0]

  postGame3:
    players: [ 'p1' ]
  postGameRes3:
    players: [ 'p1' ]
    waiting: [ ]
    type: 'rule/v1'
    status: "active"
    url: config.gameServers[0]

  leaveGameRes:
    players: [ 'p1', 'p2' ]
    waiting: [ 'p2' ]
    type: 'rule/v1'
    status: "inactive"
    url: config.gameServers[0]

# vim: ts=2:sw=2:et:
