expect = require 'expect.js'
supertest = require 'supertest'
sinon = require 'sinon'
fakeRedis = require 'fakeredis'
authdb = require 'authdb'

config = require '../config'
helpers = require './helpers'
samples = require './sample-data'
Server = require '../src/server'
Games = require '../src/games'

process.env.API_SECRET = "1234"

coordinatorApi = require "../src/coordinator-api"
coordinatorNotifications = require "../src/coordinator-notifications"

endpoint = (path) ->
  return "/#{config.routePrefix}#{path || ''}"

describe "Coordinator API", ->

  sendNotificationSpy = null
  go = null
  server = null
  port = 1337

  beforeEachIteration = 0

  beforeEach (done) ->
    beforeEachIteration = beforeEachIteration + 1
    server = Server.createServer()
    go = supertest.bind(supertest, server)
    authdbClient = authdb.createClient({
      redisClient: fakeRedis.createClient("fake-auth-#{beforeEachIteration}")
    })
    sendNotificationSpy = sinon.spy()

    for own username, data of samples.users
      authdbClient.addAccount data.token, data.account

    games = new Games
    games.initialize callback: (err) ->
      api = coordinatorApi.create
        authdbClient: authdbClient
        games: games
        sendNotification: sendNotificationSpy
      api.addRoutes(endpoint(), server)
      server.listen port++, ->
        helpers.initDb (err, db_) ->
          db = db_
          done(err)

  afterEach (done) ->
    server.close ->
      helpers.dropDb(done)

  describe "GET /games/:id", ->
    it 'returns a game the player is playing', (done) ->
      go()
        .get endpoint("/auth/p1-token/games/0000000000000000001")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          res.body._id = res.body.id
          delete res.body.id
          expect(res.body).to.eql(samples.docs[0])
          done()

    it "won't return a game the player isn't playing", (done) ->
      go()
        .get endpoint("/auth/p1-token/games/0000000000000000003")
        .expect 401, done

    it 'allows logging in via API_SECRET', (done) ->
      username = samples.users.p1.account.username
      gameId = 'games/0000000000000000001'

      go()
        .get(endpoint "/auth/#{process.env.API_SECRET}.#{username}/#{gameId}")
        .expect 200, done

  describe "GET /active-games", ->
    it 'fetches the list of active games', (done) ->
      go()
        .get endpoint("/auth/p1-token/rule/v1/active-games")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.eql([{
            id: '0000000000000000001'
            type: 'rule/v1'
            players: [ 'p1', 'p2' ]
            url: 'http://fovea.cc'
            status: 'active'
          }, {
            id: '0000000000000000002'
            type: 'rule/v1'
            players: [ 'p3', 'p1' ]
            url: 'http://fovea.cc'
            status: 'active'
          }])
          done()

  describe "POST /games", ->
    it 'adds games to the list', (done) ->
      go()
        .post endpoint("/auth/p1-token/rule/v1/games")
        .send samples.postGame
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          samples.postGameRes.id = res.body.id
          expect(res.body).to.eql(samples.postGameRes)
          done()

    it 'adds the game activated if 1 player only', (done) ->
      go()
        .post endpoint("/auth/p1-token/rule/v1/games")
        .send samples.postGame3
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          samples.postGameRes3.id = res.body.id
          expect(res.body).to.eql(samples.postGameRes3)
          done()

  postTestGame = (done) ->
    go()
      .post endpoint("/auth/p1-token/rule/v1/games")
      .send samples.postGame
      .end (err, res) ->
        expect(err).to.be(null)
        samples.postGameRes.id = res.body.id
        expect(res.body).to.eql(samples.postGameRes)
        done()

  p2Join = (done) ->
    id = samples.postGameRes.id
    samples.postGameRes2.id = id
    go()
      .post endpoint("/auth/p2-token/games/#{id}/join")
      .expect 200
      .end (err, res) ->
        expect(err).to.be(null)
        expect(res.body).to.eql(samples.postGameRes2)
        done()

  p2Leave = (reason, done) ->
    if typeof reason == 'function'
      done = reason
      reason = undefined
    id = samples.postGameRes.id
    samples.leaveGameRes.id = id
    goPost = go()
      .post endpoint("/auth/p2-token/games/#{id}/leave")
      .expect 200
    if reason
      goPost = goPost.send reason:reason
    goPost.end (err, res) ->
      expect(err).to.be(null)
      done()

  describe "POST /games/:id/join", ->

    beforeEach postTestGame

    it 'allows only waiting players to join', (done) ->
      id = samples.postGameRes.id
      go()
        .post endpoint("/auth/p3-token/games/#{id}/join")
        .expect 401, done

    it 'allows waiting players to join', (done) ->
      id = samples.postGameRes.id
      samples.postGameRes2.id = id
      go()
        .post endpoint("/auth/p2-token/games/#{id}/join")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.eql(samples.postGameRes2)
          done()

    it 'sends notification to other active players, when someone joins', () ->
      # p2 joined a game `samples.postGameRes` with players [p1, p2],
      # expect sendNotification() to be called once for notifying p1.
      id = samples.postGameRes.id
      samples.postGameRes2.id = id
      go()
        .post endpoint("/auth/p2-token/games/#{id}/join")
        .expect 200
        .end (err, res) ->
          expect(sendNotificationSpy.calledOnce).to.be(true)
          notification = sendNotificationSpy.firstCall.args[0]
          expect(notification.to).to.be('p1')
          expect(notification.data.player).to.be('p2')
          expect(notification.type).to.be(coordinatorNotifications.JOIN)

  describe "POST /games/:id/leave", ->

    beforeEach postTestGame
    beforeEach p2Join

    it 'rejects non participating players', (done) ->
      id = samples.postGameRes.id
      go()
        .post endpoint("/auth/p3-token/games/#{id}/leave")
        .expect 401, done

    it 'allows non-waiting players to leave', (done) ->
      id = samples.postGameRes.id
      samples.leaveGameRes.id = id
      go()
        .post endpoint("/auth/p2-token/games/#{id}/leave")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.eql(samples.leaveGameRes)
          done()

    it 'rejects non waiting players', (done) ->
      p2Leave ->
        id = samples.postGameRes.id
        go()
          .post endpoint("/auth/p2-token/games/#{id}/leave")
          .expect 403, done

    it 'notifies other active players wnen someone leaves', (done) ->
      p2Leave ->
        # p2 left game `samples.postGameRes` with players [p1, p2],
        # expect sendNotification() to be called once for notifying p1.
        # (first call was for the beforeEach's p2 join)
        expect(sendNotificationSpy.calledTwice).to.be(true)
        notification = sendNotificationSpy.secondCall.args[0]
        expect(notification.to).to.be('p1')
        expect(notification.data.player).to.be('p2')
        expect(notification.type).to.be(coordinatorNotifications.LEAVE)
        done()

    it 'notifies other active players of undefined reason', (done) ->
      p2Leave ->
        notification = sendNotificationSpy.secondCall.args[0]
        expect(notification.data.reason).to.be(undefined)
        done()

    it 'notifies other active players of defined reason', (done) ->
      p2Leave "exit", ->
        notification = sendNotificationSpy.secondCall.args[0]
        expect(notification.data.reason).to.be("exit")
        expect(notification.data.push).to.be(undefined)
        done()

    it 'push notifies other active players when resign', (done) ->
      p2Leave "resign", ->
        notification = sendNotificationSpy.secondCall.args[0]
        expect(notification.data.reason).to.be("resign")
        expect(notification.data.push).to.be.ok()
        expect(notification.data.push).to.eql
          app: samples.postGameRes.type
          title: [ "opponent_has_left_title" ]
          message: [ "opponent_has_left_message", "p2" ]
        done()

  describe "GET /gameover", ->

    last_seq = -1
    secret = "secret=#{process.env.API_SECRET}"

    it 'requires API_SECRET', (done) ->
      go()
        .get endpoint("/gameover")
        .expect 401, done

    it 'returns all games that are over', (done) ->
      go()
        .get endpoint("/gameover?#{secret}")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(typeof res.body.last_seq).to.eql "number"
          statuses = res.body.results.map (x) -> x.status
          gameover = statuses.filter (x) -> x == "gameover"
          expect(gameover.length).to.eql statuses.length
          last_seq = res.body.last_seq
          done()

    it 'listen for changes', (done) ->
      since = "since=#{last_seq}"
      id = samples.docs[0]._id
      go()
        .get endpoint("/gameover?#{secret}&#{since}")
        .expect 200
        .end (err, res) ->
          expect(res.body.last_seq).to.eql(last_seq + 1)
          expect(res.body.results.length).to.eql(1)
          done()
      go()
        .post endpoint("/auth/p1-token/games/#{id}/gameover")
        .send gameOverData: { dummy: "indeed" }
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)

# vim: ts=2:sw=2:et:
