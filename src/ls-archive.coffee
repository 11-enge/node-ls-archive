fs = require 'fs'
path = require 'path'
util = require 'util'

class ArchiveEntry
  constructor: (@path, @type) ->
    @children = [] if @isDirectory()

  add: (entry) ->
    return false unless @isParentOf(entry)

    segments = entry.getPath().substring(@getPath().length + 1).split(path.sep)
    return false if segments.length is 0

    if segments.length is 1
      @children.push(entry)
      true
    else
      name = segments[0]
      child = findEntryWithName(@children, name)
      unless child?
        child = new ArchiveEntry("#{@getPath()}#{path.sep}#{name}", 5)
        @children.push(child)
      if child.isDirectory()
        child.add(entry)
      else
        false

  isParentOf: (entry) ->
    @isDirectory() and entry.getPath().indexOf("#{@getPath()}#{path.sep}") is 0

  getPath: -> @path
  getName: -> @name ?= path.basename(@path)
  isFile: -> @type is 0
  isDirectory: -> @type is 5
  isSymbolicLink: -> @type is 2
  toString: -> @getPath()

findEntryWithName = (entries, name) ->
  return entry for entry in entries when name is entry.getName()

convertToTree = (entries) ->
  rootEntries = []
  for entry in entries
    segments = entry.getPath().split(path.sep)
    if segments.length is 1
      rootEntries.push(entry)
    else
      name = segments[0]
      parent = findEntryWithName(rootEntries, name)
      unless parent?
        parent = new ArchiveEntry(name, 5)
        rootEntries.push(parent)
      parent.add(entry)
  rootEntries

wrapCallback = (callback) ->
  called = false
  (error, data) ->
    unless called
      error = new Error(error) if error? and not util.isError(error)
      called = true
      callback(error, data)

listZip = (archivePath, options, callback) ->
  yauzl = require 'yauzl'
  entries = []
  yauzl.open archivePath, {lazyEntries: true}, (error, zipFile) ->
    return callback(error) if error
    zipFile.readEntry()
    zipFile.on 'error', callback
    zipFile.on 'entry', (entry) ->
      if entry.fileName[-1..] is '/'
        entryPath = entry.fileName[0...-1]
        entryType = 5
      else
        entryPath = entry.fileName
        entryType = 0
      entryPath = entryPath.replace(/\//g, path.sep)
      entries.push(new ArchiveEntry(entryPath, entryType))
      zipFile.readEntry()
    zipFile.on 'end', ->
      entries = convertToTree(entries) if options.tree
      callback(null, entries)

listGzip = (archivePath, options, callback) ->
  zlib = require 'zlib'
  fileStream = fs.createReadStream(archivePath)
  fileStream.on 'error', callback
  gzipStream = fileStream.pipe(zlib.createGunzip())
  gzipStream.on 'error', callback
  listTarStream(gzipStream, options, callback)

listBzip = (archivePath, options, callback) ->
  bzip = require 'unbzip2-stream'
  fileStream = fs.createReadStream(archivePath)
  fileStream.on 'error', callback
  bzipStream = fileStream.pipe(bzip())
  bzipStream.on 'error', callback
  listTarStream(bzipStream, options, callback)

listTar = (archivePath, options, callback) ->
  fileStream = fs.createReadStream(archivePath)
  fileStream.on 'error', callback
  listTarStream(fileStream, options, callback)

listTarStream = (inputStream, options, callback) ->
  entries = []
  tarStream = inputStream.pipe(require('tar').Parse())
  tarStream.on 'error', callback
  tarStream.on 'entry', (entry) ->
    if entry.props.path[-1..] is '/'
      entryPath = entry.props.path[0...-1]
    else
      entryPath = entry.props.path
    entryType = parseInt(entry.props.type)
    entryPath = entryPath.replace(/\//g, path.sep)
    entries.push(new ArchiveEntry(entryPath, entryType))
  tarStream.on 'end', ->
    entries = convertToTree(entries) if options.tree
    callback(null, entries)

readFileFromZip = (archivePath, filePath, callback) ->
  yauzl = require 'yauzl'
  yauzl.open archivePath, {lazyEntries: true}, (error, zipFile) ->
    return callback(error) if error
    zipFile.readEntry()
    zipFile.on 'error', callback
    zipFile.on 'end', ->
      callback("#{filePath} does not exist in the archive: #{archivePath}")
    zipFile.on 'entry', (entry) ->
      return zipFile.readEntry() unless filePath is entry.fileName.replace(/\//g, path.sep)

      if filePath[-1..] isnt path.sep
        zipFile.openReadStream entry, (error, entryStream) ->
          return callback(error) if error
          readEntry(entryStream, callback)
      else
        callback("#{filePath} is not a normal file in the archive: #{archivePath}")

readFileFromGzip = (archivePath, filePath, callback) ->
  fileStream = fs.createReadStream(archivePath)
  fileStream.on 'error', callback
  gzipStream = fileStream.pipe(require('zlib').createGunzip())
  gzipStream.on 'error', callback
  gzipStream.on 'end', ->
    callback("#{filePath} does not exist in the archive: #{archivePath}")
  readFileFromTarStream(gzipStream, archivePath, filePath, callback)

readFileFromBzip = (archivePath, filePath, callback) ->
  fileStream = fs.createReadStream(archivePath)
  fileStream.on 'error', callback
  bzipStream = fileStream.pipe(require('unbzip2-stream')())
  bzipStream.on 'error', callback
  bzipStream.on 'end', ->
    callback("#{filePath} does not exist in the archive: #{archivePath}")
  readFileFromTarStream(bzipStream, archivePath, filePath, callback)

readFileFromTar = (archivePath, filePath, callback) ->
  fileStream = fs.createReadStream(archivePath)
  fileStream.on 'error', callback
  fileStream.on 'end', ->
    callback("#{filePath} does not exist in the archive: #{archivePath}")
  readFileFromTarStream(fileStream, archivePath, filePath, callback)

readFileFromTarStream = (inputStream, archivePath, filePath, callback) ->
  tar = require 'tar'
  tarStream = inputStream.pipe(tar.Parse())

  tarStream.on 'error', callback
  tarStream.on 'entry', (entry) ->
    return unless filePath is entry.props.path.replace(/\//g, path.sep)

    if entry.props.type is '0'
      readEntry(entry, callback)
    else
      callback("#{filePath} is not a normal file in the archive: #{archivePath}")

readEntry = (entry, callback) ->
  contents = []
  entry.on 'data', (data) -> contents.push(data)
  entry.on 'end', -> callback(null, Buffer.concat(contents))

isTarPath = (archivePath) ->
  path.extname(archivePath) is '.tar'

isZipPath = (archivePath) ->
  extension = path.extname(archivePath)
  extension in ['.epub', '.jar', '.love', '.war', '.zip', '.egg', '.whl', '.xpi', '.nupkg']

isGzipPath = (archivePath) ->
  path.extname(archivePath) is '.tgz' or
    path.extname(path.basename(archivePath, '.gz')) is '.tar'

isBzipPath = (archivePath) ->
  path.extname(archivePath) is '.tbz' or
    path.extname(archivePath) is '.tbz2' or
      path.extname(path.basename(archivePath, '.bz2')) is '.tar'

module.exports =
  isPathSupported: (archivePath) ->
    return false unless archivePath
    isTarPath(archivePath) or
      isZipPath(archivePath) or
        isGzipPath(archivePath) or
          isBzipPath(archivePath)

  list: (archivePath, options={}, callback) ->
    if typeof options is 'function'
      callback = options
      options = {}

    if isTarPath(archivePath)
      listTar(archivePath, options, wrapCallback(callback))
    else if isGzipPath(archivePath)
      listGzip(archivePath, options, wrapCallback(callback))
    else if isBzipPath(archivePath)
      listBzip(archivePath, options, wrapCallback(callback))
    else if isZipPath(archivePath)
      listZip(archivePath, options, wrapCallback(callback))
    else
      callback(new Error("'#{path.extname(archivePath)}' files are not supported"))
    undefined

  readFile: (archivePath, filePath, callback) ->
    if isTarPath(archivePath)
      readFileFromTar(archivePath, filePath, wrapCallback(callback))
    else if isGzipPath(archivePath)
      readFileFromGzip(archivePath, filePath, wrapCallback(callback))
    else if isBzipPath(archivePath)
      readFileFromBzip(archivePath, filePath, wrapCallback(callback))
    else if isZipPath(archivePath)
      readFileFromZip(archivePath, filePath, wrapCallback(callback))
    else
      callback(new Error("'#{path.extname(archivePath)}' files are not supported"))
    undefined

  readGzip: (gzipArchivePath, callback) ->
    callback = wrapCallback(callback)

    zlib = require 'zlib'
    fileStream = fs.createReadStream(gzipArchivePath)
    fileStream.on 'error', callback
    gzipStream = fileStream.pipe(zlib.createGunzip())
    gzipStream.on 'error', callback

    chunks = []
    gzipStream.on 'data', (chunk) ->
      chunks.push(chunk)
    gzipStream.on 'end', ->
      callback(null, Buffer.concat(chunks))
  
  readBzip: (bzipArchivePath, callback) ->
    callback = wrapCallback(callback)
    
    bzip = require 'unbzip2-stream'
    fileStream = fs.createReadStream(bzipArchivePath)
    fileStream.on 'error', callback
    bzipStream = fileStream.pipe(bzip())
    bzipStream.on 'error', callback
    
    chunks = []
    bzipStream.on 'data', (chunk) ->
      chunks.push(chunk)
    bzipStream.on 'end', ->
      callback(null, Buffer.concat(chunks))
