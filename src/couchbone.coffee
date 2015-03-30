class Model
  constructor: (obj, db) ->
    # This keys don't get saved to couch
    @COUCH_KEYS_IGNORED = [
      'id'
      'db'
      'COUCH_KEYS_IGNORED'
      'COUCH_KEYS_MAPPING'
    ]

    # Which keys from couch docs get translated to other keys
    # (null means key won't be present)
    @COUCH_KEYS_MAPPING =
      _id: 'id'
      _rev: null

    @db = db
    @fromCouch obj

  fromCouch: () ->
    Object.keys(obj).forEach (key) ->
      thisKey = key
      if @COUCH_KEYS_MAPPING.hasOwnProperty(key)
        if @COUCH_KEYS_MAPPING[key] == null
          return

        thisKey = @COUCH_KEYS_MAPPING[key]

      this[thisKey] = obj[key]
    , @

  toCouch: () ->
    doc = {}
    Object.keys(this).forEach (key) ->
      if -1 == @COUCH_KEYS_IGNORED.indexOf(key)
        doc[key] = this[key]
    , @

    return doc

  fetch: (callback) ->
    @db.get @id, (err, doc) ->
      if !err
        @fromCouch doc
      callback err, @

  save: (callback) ->
    @db.insert @toCouch(), @hasOwnProperty('id') && @id, (err, result) ->
      if !err
        @fromCouch result
      callback err, @

class Collection
  constructor: (db, Model) ->
    @db = db
    @Model = Model
    @models = []

  fromArray: (rows) ->
    @models = rows
      .map (r) -> new @Model(r, @db)

  newModel: (obj) ->
    m = new @Model(obj, @db)
    @models.push m
    m

  fetch: (options, callback) ->
    if arguments.length == 1
      callback = options
      options = {}

    design = @design
    if options.design
      design = options.design
      delete options.design

    view = @view
    if options.view
      view = options.view
      delete options.view
  
    # before = timestamp(options.before)
    # options =
    #  startkey: [@type]
    #  endkey: [@type, {}]
    #  limit: options.limit || DEFAULT_LIMIT
    # if (before)
    #   options.startkey.push(1 - before)
  
    @db.view design , view, options, (err, result, headers) ->
      if (err)
        # Query parse errors have lower severity level, so we use WARN for them.
        method = if err.error == 'query_parse_error' then 'warn' else 'error'
        log[method] "Failed to query _#{design}/#{view}",
          err: err,
          options: options
          headers: headers
  
        return callback(err)
  
      values = result.rows.map (row) -> row.value
      @fromArray values
      callback(null, @)

module.exports =
  Model: Model
  Collection: Collection
# vim: ts=2:sw=2:et: