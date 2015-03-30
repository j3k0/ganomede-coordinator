nano = require 'nano'
vasync = require 'vasync'
log = require './log'

DEFAULT_LIMIT = 25

timestamp = (n) ->
  if n instanceof Date then n.getTime() else n

views = do () ->
  result = {}
  funcs =
    # Challenges
    # sorted by (start desc)
    'challenges':
      map: (doc) ->
        if doc._id.slice(0, 10) == 'challenge:'
          emit [doc.type, -doc.start],
            id: doc._id
            start: doc.start
            end: doc.end,
            type: doc.type
            gameData: doc.gameData

    # Entries by challenge
    # sorted by (score desc) (time asc)
    'leaderboards':
      map: (doc) ->
        if doc._id.slice(0, 6) == 'entry:' && doc.moves && doc.moves.length > 0
          start = doc.moves[0].timestamp
          end = doc.moves[doc.moves.length - 1].timestamp
          time = end - start

          # challengeId, highest score, lowest time
          emit [doc.challengeId, -doc.score, time],
            username: doc.username
            score: doc.score
            time: time

    # User's entries
    # sorted by (start desc)
    'user_entries':
      map: (doc) ->
        if doc._id.slice(0, 6) == 'entry:' && doc.moves && doc.moves.length > 0
          start = doc.moves[0].timestamp
          end = doc.moves[doc.moves.length - 1].timestamp
          time = end - start

          # username, -start
          emit [doc.username, -start],
            id: doc._id
            challengeId: doc.challengeId
            start: start
            score: doc.score
            time: time

  for own view, mapReduce of funcs
    result[view] =
      map: String(mapReduce.map)

  return result

class DB
  constructor: (dbname, serverUri, designName) ->
    @db = nano(serverUri).use(dbname)
    @designName = designName

  # Gets doc by its id.
  get: (id, callback) ->
    @db.get id, (err, doc, headers) ->
      if err && !(err.error == 'not_found' && err.reason == 'missing')
        log.error 'Failed to retrieve Couch doc',
          err: err,
          _id: id,
          headers: headers
        return callback(err)

      if err || !doc
        return callback(null, null)

      callback(null, doc)

  # Saves doc to couch
  insert: (doc, customId, callback) ->
    cb = (err, result, headers) ->
      if (err)
        log.error 'Failed to save doc to Couch',
          err: err
          doc: doc
          customId: customId
          result: result
          headers: headers
        return callback(err)

      callback(null, result)

    args = if customId then [doc, customId, cb] else [doc, cb]
    @db.insert.apply(@db, args)

  # Lists challenges where `challenge.type == @type`.
  # (views.challenges)
  #
  # Options:
  #   before: will only include challeneges where
  #           `challenge.start < options.before`
  #   limit: will include at most limit challenges.
  #
  # callback(err, objects.ChallengesList)
  #challenges: (options, callback) ->
  #  if arguments.length == 1
  #    callback = options
  #    options = {}
  #
  #  before = timestamp(options.before)
  #  qs =
  #    startkey: [@type]
  #    endkey: [@type, {}]
  #    limit: options.limit || DEFAULT_LIMIT
  #
  #  if (before)
  #    qs.startkey.push(1 - before)
  #
  #  @db.view designName, 'challenges', qs, (err, result, headers) ->
  #    if (err)
  #      # Query parse errors have lower severity level,
  #      # so we use WARN for them.
  #      method = if err.error == 'query_parse_error' then 'warn' else 'error'
  #      log[method] "Failed to query _#{designName}/challenges",
  #        err: err,
  #        qs: qs
  #        headers: headers
  #
  #      return callback(err)
  #
  #    values = result.rows.map (row) -> row.value
  #    callback(null, new objects.ChallengesList(values))

  # Lists all the entries where `entry.challengeId = challengeId`
  # (views.leaderboards)
  #
  # callback(err, objects.EntriesList)
  #leaderboard: (challengeId, options, callback) ->
  #  if arguments.length == 2
  #    callback = options
  #    options = {}
  #
  #  qs =
  #    startkey: [challengeId]
  #    endkey: [challengeId, {}]
  #
  #  if options.hasOwnProperty('limit')
  #    qs.limit = options.limit
  #
  #  @db.view designName, 'leaderboards', qs, (err, result, headers) ->
  #    if (err)
  #      log.error "Failed to query _#{designName}/leaderboards",
  #        err: err
  #        qs: qs
  #        headers: headers
  #      return callback(err)
  #
  #    values = result.rows.map (row) -> row.value
  #    callback(null, new objects.EntriesList(challengeId, values))

  # Lists user's entries where `entry.username == username`.
  # (views.user_entries)
  #
  # Options:
  #   before: will only include entries where
  #           `entry.start < options.before`
  #   limit: will include at most limit entries.
  #
  # callback(err, [objects.Entry])
  #user_entries: (username, options, callback) ->
  #  if arguments.length == 2
  #    callback = options
  #    options = {}
  #
  #  before = timestamp(options.before)
  #  qs =
  #    startkey: [username]
  #    endkey: [username, {}]
  #    limit: options.limit || DEFAULT_LIMIT
  #
  #  before = timestamp(options.before)
  #  if (before)
  #    qs.startkey.push(1 - before)
  #
  #  @db.view designName, 'user_entries', qs, (err, result, headers) ->
  #    if err
  #      log.error "Failed to query _#{designName}/user_entries",
  #        err: err
  #        qs: qs
  #        headers: headers
  #      return callback(err)
  #
  #    entries = result.rows.map (row) -> new objects.Entry(row.value)
  #    callback(null, entries)

  # callback(err, db_exists, design_doc)
  #@_init_get_info: (db, callback) ->
  #  db.get "_design/#{designName}", (err, doc, headers) ->
  #    if err && err.error != 'not_found'
  #      log.error 'Faield to query design doc',
  #        err: err
  #        headers: headers
  #      return callback(err)
  #
  #    # 404
  #    if err
  #      if err.reason == 'no_db_file'
  #        return callback(null, false, null)
  #      else if err.reason == 'missing'
  #        return callback(null, true, null)
  #      else
  #        return callback(err)
  #
  #    callback(null, true, doc)

  # callback(err, insertResult, insertHeaders)
  #@_init_save_views_if_different: (db, design, callback) ->
  #  dbViews = design.views
  #  changed = {}
  #
  #  for own name, mapReduce of views
  #    if dbViews?[name]?.map != mapReduce.map
  #      changed[name] = mapReduce
  #
  #  # Everything's in place
  #  if Object.keys(changed).length == 0
  #    return process.nextTick(callback.bind(null, null))
  #
  #  # Some stuff is different
  #  log.info "Design doc in database `_design/#{designName}` is different from
  #            design doc in app, recreating…",
  #    db_views: {views: design.views}
  #    app_views: {views: views}
  #    diff: changed
  #
  #  doc = {views: views, _rev: design._rev}
  #  db.insert doc, "_design/#{designName}", callback

  # This will create Couch database @dbname at @serverUri
  # and create design doc _design/designName with {views: views}.
  #
  # In case design doc exists, it will replace it with {views: views}
  # in case any views are different from the ones in this file.
  #
  # callback(err, DB instance)
  @initialize: (options, callback) ->

    dbname = options.name
    serverUri = options.serverUri
    designName = options.designName

    log.info "Initializing database `#{dbname}` at `#{serverUri}`"
    unless serverUri && dbname
      throw new Error('serverUri and dbname are required')

    couch = nano(serverUri)
    db = couch.use(dbname)

    vasync.waterfall [
      (cb) -> DB._init_get_info(db, cb)
      (db_exists, design, cb) ->
        if !design
          if !db_exists
            log.info "Database `#{dbname}` is missing, recreating…"
          log.info "Design doc `_design/#{designName}` is missing, recreating…"

          doc = {views: views}
          createFn = couch.db.create.bind(couch.db, dbname)
          insertFn = db.insert.bind(db, doc, "_design/#{designName}", cb)
          return if db_exists then insertFn() else createFn(insertFn)

        # Check for missing
        DB._init_save_views_if_different(db, design, cb)

    ], (err, results) ->
      if (err)
        log.error "Failed to initialize DB",
          err: err
          dbname: dbname
          type: type
          serverUri: serverUri
        return callback(err)

      callback(null, new DB(dbname, type, serverUri, designName))

module.exports = DB
# vim: ts=2:sw=2:et: