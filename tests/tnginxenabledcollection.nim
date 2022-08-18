import
  tiny_container_manager/collection,
  tiny_container_manager/collection_test_utils,
  tiny_container_manager/container,
  tiny_container_manager/nginx,
  tiny_container_manager/shell_utils,
  asyncdispatch,
  std/os,
  std/sequtils,
  std/strformat,
  std/sugar,
  std/tempfiles,
  nim_utils/logline


proc mkExpectedProc(x: seq[EnabledLink]): () -> Future[seq[EnabledLink]] =
  proc f(): Future[seq[EnabledLink]] {.async.} =
    return x
  return f

proc mkMockLink(enabledDir: string, targetDir: string): EnabledLink =
  let filename = "mock.conf"
  EnabledLink(
    filePath: enabledDir / filename,
    target: targetDir / filename
  )

let cc = newContainersCollection()
let ncc = newConfigsCollection(cc, dir = createTempDir("",""))
block CreateOneIdempotent:
  let tmpDir = createTempDir("","")
  let nec = newEnabledCollection(ncc, tmpDir)
  let mockSymlink  = mkMockLink(nec.enabledDir, ncc.dir)
  nec.disableOnChange()
  nec.getExpected = mkExpectedProc @[mockSymlink]

  let startingState = waitFor nec.getWorldState()
  assert len(startingState) == 0
  let changes = waitFor nec.ensure()
  assert len(changes.added) == 1
  assert len(changes.removed) == 0
  let endState = waitFor nec.getWorldState()
  logDebug fmt"nec.enabledDir: {nec.enabledDir}"
  logDebug fmt"endState: {endState}"
  assert len(endState) == 1

  let changes2 = waitFor nec.ensure()
  assert len(changes2.removed) == 0
  assert len(changes2.added) == 0
  let endState2 = waitFor nec.getWorldState()
  assert len(endState2) == 1

block RemoveOne:
  let tmpDir = createTempDir("","")
  let nec = newEnabledCollection(ncc, tmpDir)
  nec.disableOnChange()
  nec.getExpected = mkExpectedProc @[]
  let extraFile = tmpDir / "extra.conf"
  extraFile.createFile

  let startingState = waitFor nec.getWorldState()
  assert len(startingState) == 1
  let changes = waitFor nec.ensure()
  assert len(changes.added) == 0
  assert len(changes.removed) == 1
  let endState = waitFor nec.getWorldState()
  assert len(endState) == 0


