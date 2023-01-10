import
    ./config_collection,
    ./core,
    ./conffile,
    ../collection,
    asyncdispatch,
    os,
    sequtils,
    sugar,
    strformat,
    nim_utils/[
        logline,
        files
    ]

type
  EnabledLink* = object of RootObj
    filePath*: string
    target*: string
  NginxEnabledFile* = object of RootObj
    filePath*: string
  NginxEnabledCollection* = ref object of ManagedCollection[EnabledLink, NginxEnabledFile]
    enabledDir*: string

proc getExpectedEnabledFiles(ncc: NginxConfigsCollection, enabledDir: string): Future[seq[EnabledLink]] {.async.} =
  let nginxConfs = await ncc.getExpected()
  result = collect(newSeq):
    for n in nginxConfs:
      let filename = n.filename
      let target = ncc.dir / filename
      let filePath = enabledDir / filename
      # Only care about enabled files if the available file exists
      if target.fileExists:
        EnabledLink(filePath: filePath, target: target)

proc getActualEnabledFiles(dir: string): seq[NginxEnabledFile] =
  return collectFilesInDir(dir).mapIt(NginxEnabledFile(filePath: it))

proc compare(e: EnabledLink, f: NginxEnabledFile): bool =
  if e.filePath != f.filePath:
    return false
  let actualFileType = f.filePath.fileType
  if actualFileType != ftSymlink:
    return false
  return f.filePath.expandSymlink == e.target

proc createSymlink(e: EnabledLink) {.async.} =
  logDebug fmt"Creating symlink from {e.filePath} to {e.target}"
  createSymlink(e.target, e.filePath)

proc newEnabledCollection*(ncc: NginxConfigsCollection, enabledDir: string): NginxEnabledCollection =
  proc getWorldState(): Future[seq[NginxEnabledFile]] {.async.} =
    return getActualEnabledFiles(enabledDir)

  proc remove(e: NginxEnabledFile) {.async.} =
    logDebug fmt"Trying to remove nginxConfig {e.filePath}"
    removePath(e.filePath)

  NginxEnabledCollection(
    getExpected: () => getExpectedEnabledFiles(ncc, enabledDir),
    getWorldState: getWorldState,
    matches: compare,
    remove: remove,
    create: createSymlink,
    onChange: (cr: ChangeResult[EnabledLink, NginxEnabledFile]) => onNginxChange(),
    enabledDir: enabledDir
  )