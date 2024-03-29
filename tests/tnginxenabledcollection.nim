import
  asyncdispatch,
  os,
  sequtils,
  strformat,
  std/tempfiles,
  nim_utils/logline,
  tiny_container_manager/[
    collection,
    container,
    container_collection,
    nginx/config_collection,
    nginx/enabled_collection,
    shell_utils
  ],
  test_utils/[
    collection_testing,
  ]


proc mkMockLink(enabledDir: string, targetDir: string): EnabledLink =
  let filename = "mock.conf"
  EnabledLink(
    filePath: enabledDir / filename,
    target: targetDir / filename
  )

let cc = newContainersCollection()
let ncc = newConfigsCollection(cc, dir = createTempDir("",""), useHttps = false)
block CreateOneIdempotent:
  let tmpDir = createTempDir("","")
  let nec = newEnabledCollection(ncc, tmpDir)
  let mockSymlink  = mkMockLink(nec.enabledDir, ncc.dir)
  nec.disableOnChange()
  nec.mkExpected @[mockSymlink]

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
  nec.mkExpected @[]
  let extraFile = tmpDir / "extra.conf"
  extraFile.createFile

  let startingState = waitFor nec.getWorldState()
  assert len(startingState) == 1
  let changes = waitFor nec.ensure()
  assert len(changes.added) == 0
  assert len(changes.removed) == 1
  let endState = waitFor nec.getWorldState()
  assert len(endState) == 0


