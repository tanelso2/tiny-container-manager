import
  asyncdispatch,
  os,
  strformat,
  sugar

import
  nim_utils/[
    files,
    logline
  ]

import
  tiny_container_manager/[
    collection,
    collection_test_utils,
    container,
    docker
  ]

let testC = newContainer(spec = ContainerSpec(
  name: "test",
  image: "nginx:latest",
  containerPort: 80,
  host: "example.com"
))

proc mkExpectedProc(x: seq[Container]): () -> Future[seq[Container]] =
  proc f(): Future[seq[Container]] {.async.} =
    return x
  return f

if dockerRunning():
  block CleanSlate:
    let cc = newContainersCollection()
    cc.disableOnChange()
    cc.getExpected = mkExpectedProc @[]

    discard waitFor cc.ensure()
    let cleanState = waitFor cc.getWorldState()
    assert len(cleanState) == 0

  block CreateOneIdempotent:
    let cc = newContainersCollection()
    cc.disableOnChange()
    cc.getExpected = mkExpectedProc @[testC]

    let startingState = waitFor cc.getWorldState()
    assert len(startingState) == 0

    let changes = waitFor cc.ensure()
    assert len(changes.added) == 1
    assert len(changes.removed) == 0
    let endState = waitFor cc.getWorldState()
    assert len(endState) == 1

    let changes2 = waitFor cc.ensure()
    assert len(changes2.removed) == 0
    assert len(changes2.added) == 0
    let endState2 = waitFor cc.getWorldState()
    assert len(endState2) == 1
  block RemoveOneIdempotent:
    let cc = newContainersCollection()
    cc.disableOnChange()
    cc.getExpected = mkExpectedProc @[]

    let startingState = waitFor cc.getWorldState()
    # 1 left over from last block
    assert len(startingState) == 1

    let changes = waitFor cc.ensure()
    assert len(changes.added) == 0
    assert len(changes.removed) == 1
    let endState = waitFor cc.getWorldState()
    assert len(endState) == 0

    let changes2 = waitFor cc.ensure()
    assert len(changes2.removed) == 0
    assert len(changes2.added) == 0
    let endState2 = waitFor cc.getWorldState()
    assert len(endState2) == 0

