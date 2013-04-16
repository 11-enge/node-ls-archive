archive = require '../lib/ls-archive'
path = require 'path'

describe "zip files", ->
  fixturesRoot = null

  beforeEach ->
    fixturesRoot = path.join(__dirname, 'fixtures')

  describe ".list()", ->
    describe "when the archive file exists", ->
      it "returns files in the zip archive", ->
        zipPaths = null
        callback = (error, paths) -> zipPaths = paths
        archive.list(path.join(fixturesRoot, 'one-file.zip'), callback)
        waitsFor -> zipPaths?
        runs ->
          expect(zipPaths.length).toBe 1
          expect(zipPaths[0].path).toBe 'file.txt'
          expect(zipPaths[0].isDirectory()).toBe false
          expect(zipPaths[0].isFile()).toBe true
          expect(zipPaths[0].isSymbolicLink()).toBe false

      it "returns folders in the zip archive", ->
        zipPaths = null
        callback = (error, paths) -> zipPaths = paths
        archive.list(path.join(fixturesRoot, 'one-folder.zip'), callback)
        waitsFor -> zipPaths?
        runs ->
          expect(zipPaths.length).toBe 1
          expect(zipPaths[0].path).toBe 'folder'
          expect(zipPaths[0].isDirectory()).toBe true
          expect(zipPaths[0].isFile()).toBe false
          expect(zipPaths[0].isSymbolicLink()).toBe false

    describe "when the archive path does not exist", ->
      it "calls back with an error", ->
        archivePath = path.join(fixturesRoot, 'not-a-file.zip')
        pathError = null
        callback = (error) -> pathError = error
        archive.list(archivePath, callback)
        waitsFor -> pathError?
        runs -> expect(pathError.message.length).toBeGreaterThan 0

    describe "when the archive path isn't a valid zip file", ->
      it "calls back with an error", ->
        archivePath = path.join(fixturesRoot, 'invalid.zip')
        pathError = null
        callback = (error) -> pathError = error
        archive.list(archivePath, callback)
        waitsFor -> pathError?
        runs -> expect(pathError.message.length).toBeGreaterThan 0

  describe ".readFile()", ->
    describe "when the path exists in the archive", ->
      it "calls back with the contents of the given path", ->
        archivePath = path.join(fixturesRoot, 'one-file.zip')
        pathContents = null
        callback = (error, contents) -> pathContents = contents
        archive.readFile(archivePath, 'file.txt', callback)
        waitsFor -> pathContents?
        runs -> expect(pathContents).toBe 'hello\n'

    describe "when the path does not exist in the archive", ->
      it "calls back with an error", ->
        archivePath = path.join(fixturesRoot, 'one-file.zip')
        pathError = null
        callback = (error, contents) -> pathError = error
        archive.readFile(archivePath, 'not-a-file.txt', callback)
        waitsFor -> pathError?
        runs -> expect(pathError.message.length).toBeGreaterThan 0

    describe "when the archive path does not exist", ->
      it "calls back with an error", ->
        archivePath = path.join(fixturesRoot, 'not-a-file.zip')
        pathError = null
        callback = (error, contents) -> pathError = error
        archive.readFile(archivePath, 'not-a-file.txt', callback)
        waitsFor -> pathError?
        runs -> expect(pathError.message.length).toBeGreaterThan 0

    describe "when the archive path isn't a valid zip file", ->
      it "calls back with an error", ->
        archivePath = path.join(fixturesRoot, 'invalid.zip')
        pathError = null
        callback = (error, contents) -> pathError = error
        archive.readFile(archivePath, 'invalid.txt', callback)
        waitsFor -> pathError?
        runs -> expect(pathError.message.length).toBeGreaterThan 0

    describe "when the path is a folder", ->
      it "calls back with an error", ->
        archivePath = path.join(fixturesRoot, 'one-folder.zip')
        pathError = null
        callback = (error, contents) -> pathError = error
        archive.readFile(archivePath, 'folder/', callback)
        waitsFor -> pathError?
        runs -> expect(pathError.message.length).toBeGreaterThan 0
