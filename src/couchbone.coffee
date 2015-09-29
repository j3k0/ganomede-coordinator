class Model
  constructor: (obj, db) ->
    # This keys don't get saved to couch
    @COUCH_KEYS_IGNORED = [
      'id'
      'rev'
      'db'
      'ok'
      'COUCH_KEYS_IGNORED'
      'COUCH_KEYS_MAPPING'
    ]

    # Which keys from couch docs get translated to other keys
    # (null means key won't be present)
    @COUCH_KEYS_MAPPING =
      _id: 'id'
      _rev: 'rev'
      ok: null

    @db = db
    if (obj)
      @fromCouch obj

  fromCouch: (obj) ->
    if !obj
      return
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
    if @hasOwnProperty("rev")
      doc._rev = @rev
    return doc

  toJSON: () ->
    doc = @toCouch()
    if @hasOwnProperty("id")
      doc.id = @id
    if doc.hasOwnProperty("_rev")
      delete doc._rev
      #doc.rev = @rev
    return doc

  fetch: (callback) ->
    if !@id?
      return callback new Error("CantFetch:NoID")
    @db.get @id, (err, doc) =>
      if !err
        @fromCouch doc
      callback err, @

  save: (callback) ->
    @db.insert @toCouch(), @hasOwnProperty('id') && @id, (err, result) =>
      if !err
        @fromCouch result
      callback err, @

class Collection
  constructor: (db, Model) ->
    @db = db
    @Model = Model
    @models = []
    @fetchOptions = {}

  fromArray: (rows) ->
    @models = rows
      .map (r) => @_newModel(r)

  _newModel: (obj) ->
    new @Model(obj, @db)

  newModel: (obj) ->
    m = @_newModel(obj, @db)
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

    for own k, v of @fetchOptions
      options[k] = v
  
    # before = timestamp(options.before)
    # options =
    #  startkey: [@type]
    #  endkey: [@type, {}]
    #  limit: options.limit || DEFAULT_LIMIT
    # if (before)
    #   options.startkey.push(1 - before)
  
    if !options.limit
      options.limit = 1000000000
    @db.view design, view, options, (err, values) =>
      if (err)
        return callback(err)
      @fromArray values
      callback(null, @)

module.exports =
  Model: Model
  Collection: Collection
# vim: ts=2:sw=2:et:
