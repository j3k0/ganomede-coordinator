vasync = require 'vasync'
expect = require 'expect.js'
nano = require 'nano'
samples = require './sample-data'
Games = require '../src/games'
helpers = require './helpers'

describe 'Games', () ->

  before (done) ->
    # (Easiest thing to do is to just test it right here.)
    helpers.initDb (err, db_) ->
      db = db_
      done(err)

  after (done) ->
    helpers.dropDb(done)

  describe 'Module', () ->
    it 'creates models and collections linked with the database', (done) ->
      games = new Games
      games.initialize
        db: 12345
        callback: (err, instance) ->
          expect(instance).to.be(games)
          expect(err).to.be(null)
          model = games.newModel {}
          expect(model.db).to.be(12345)
          collection = games.activeGames "rule/v1", "my-username"
          expect(collection.db).to.be(12345)
          done()

  describe 'GameModel', () ->

    it 'should fetch content from the database', (done) ->
      games = new Games
      model = null
      vasync.waterfall [
        (cb) ->
          games.initialize callback: (err) -> cb(err)
        (cb) ->
          model = games.newModel id:samples.docs[0]._id
          model.fetch cb
      ], (err, results) ->
        expect(err).to.be(null)
        expect(model.type).to.be(samples.docs[0].type)
        expect(model.players[1]).to.be(samples.docs[0].players[1])
        expect(model.status).to.be(samples.docs[0].status)
        done()

    it 'should save entries to the DB', (done) ->
      games = new Games
      model = null
      rev = null
      vasync.waterfall [
        (cb) ->
          games.initialize callback: (err, instance) ->
            expect(err).to.be(null)
            cb err
        (cb) ->
          model = games.newModel
            data: 12345
          model.save (err) -> cb(err)
        (cb) ->
          expect(model.id).not.to.be(null)
          expect(model.rev).not.to.be(null)
          model.data = 54321
          model.save (err) -> cb(err)
          rev = model.rev
      ], (err, results) ->
        expect(err).to.be(null)
        expect(model.rev).not.to.be(rev)
        expect(model.data).to.be(54321)
        done()

  describe 'GameCollection', () ->
    it 'should fetch content from the database', (done) ->
      games = new Games
      collection = null
      vasync.waterfall [

        # Initialize DB
        (cb) ->
          games.initialize callback: (err) -> cb(err)

        # Fetch active games
        (cb) ->
          collection = games.activeGames("rule/v1", "p1")
          collection.fetch (err) -> cb(err)

        # Check that it's like samples
        (cb) ->
          expect(collection.models.length).to.equal(2)
          expect(collection.models[0].id).to.equal("0000000000000000001")
          expect(collection.models[1].id).to.equal("0000000000000000002")
          cb()

        # Insert a new model
        (cb) ->
          model = games.newModel
            type: "rule/v1"
            status: "active"
            players: [ "p1", "p2", "p3" ]
            url: "http://test"
          model.save (err) -> cb(err)

        # Fetch active games
        (cb) ->
          collection = games.activeGames("rule/v1", "p1")
          collection.fetch (err) -> cb(err)

        # Check that it's present in the list of active games
        (cb) ->
          expect(collection.models.length).to.equal(3)
          expect(collection.models[0].id).to.equal("0000000000000000001")
          expect(collection.models[1].id).to.equal("0000000000000000002")
          expect(collection.models[2].type).to.equal("rule/v1")
          expect(collection.models[2].url).to.equal("http://test")
          cb()
      ], (err, results) ->
        expect(err).to.be(null)
        done()
      null

    it 'should contains as many games as possible', (done) ->
      games = new Games
      collection = null
      vasync.waterfall [

        # Initialize DB
        (cb) ->
          games.initialize callback: (err) -> cb(err)

        # Fetch active games
        (cb) ->
          collection = games.activeGames("rule/v1", "p100")
          collection.fetch (err) -> cb(err)

        # Check that it's like samples
        (cb) ->
          console.log(collection.models.length)
          expect(collection.models.length).to.equal(100)
          cb()

      ], (err, results) ->
        expect(err).to.be(null)
        done()
      null

# vim: ts=2:sw=2:et:
